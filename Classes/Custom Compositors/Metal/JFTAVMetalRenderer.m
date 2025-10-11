//
//  JFTAVMetalRenderer.m
//  JFTAVBuilder
//
//  Created by Metal optimization for memory management
//

#import "JFTAVMetalRenderer.h"
#import <CoreImage/CoreImage.h>

@interface JFTAVMetalRenderer ()
{
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    CVMetalTextureCacheRef _textureCache;

    // Pipeline states for different filters
    id<MTLRenderPipelineState> _passthroughPipeline;
    id<MTLRenderPipelineState> _brightnessContrastPipeline;
    id<MTLRenderPipelineState> _saturationPipeline;
    id<MTLRenderPipelineState> _lutPipeline;
    id<MTLRenderPipelineState> _dissolvePipeline;

    // Vertex buffer for full-screen quad
    id<MTLBuffer> _vertexBuffer;

    // Current command buffer
    id<MTLCommandBuffer> _currentCommandBuffer;
}
@end

// Vertex structure
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} Vertex;

@implementation JFTAVMetalRenderer

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device ?: MTLCreateSystemDefaultDevice();
        if (!_device) {
            NSLog(@"[JFTAVMetalRenderer] Failed to create Metal device");
            return nil;
        }

        _commandQueue = [_device newCommandQueue];

        // Create texture cache
        CVReturn status = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                                     nil,
                                                     _device,
                                                     nil,
                                                     &_textureCache);
        if (status != kCVReturnSuccess) {
            NSLog(@"[JFTAVMetalRenderer] Failed to create texture cache: %d", status);
            return nil;
        }

        // Setup vertex buffer for full-screen quad
        [self setupVertexBuffer];

        // Load shaders and create pipeline states
        [self setupPipelines];
    }
    return self;
}

- (void)dealloc {
    if (_textureCache) {
        CVMetalTextureCacheFlush(_textureCache, 0);
        CFRelease(_textureCache);
        _textureCache = NULL;
    }
}

- (void)setupVertexBuffer {
    // Full-screen quad vertices
    static const Vertex quadVertices[] = {
        // Position,        TexCoord
        {{-1.0,  1.0},     {0.0, 0.0}},  // Top-left
        {{-1.0, -1.0},     {0.0, 1.0}},  // Bottom-left
        {{ 1.0, -1.0},     {1.0, 1.0}},  // Bottom-right

        {{-1.0,  1.0},     {0.0, 0.0}},  // Top-left
        {{ 1.0, -1.0},     {1.0, 1.0}},  // Bottom-right
        {{ 1.0,  1.0},     {1.0, 0.0}},  // Top-right
    };

    _vertexBuffer = [_device newBufferWithBytes:quadVertices
                                         length:sizeof(quadVertices)
                                        options:MTLResourceStorageModeShared];
}

- (void)setupPipelines {
    NSError *error = nil;

    // Load Metal library
    id<MTLLibrary> library = [_device newDefaultLibrary];
    if (!library) {
        // Try to find the library in the bundle
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *libraryPath = [bundle pathForResource:@"default" ofType:@"metallib"];
        if (libraryPath) {
            library = [_device newLibraryWithFile:libraryPath error:&error];
        }
    }

    if (!library) {
        NSLog(@"[JFTAVMetalRenderer] Failed to load Metal library: %@", error);
        // Create fallback simple shaders inline
        [self setupFallbackPipelines];
        return;
    }

    // Create pipeline descriptor
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    // Passthrough pipeline
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertexShader"];
    id<MTLFunction> passthroughFrag = [library newFunctionWithName:@"passthroughFragment"];

    if (vertexFunc && passthroughFrag) {
        pipelineDescriptor.vertexFunction = vertexFunc;
        pipelineDescriptor.fragmentFunction = passthroughFrag;
        _passthroughPipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        if (error) {
            NSLog(@"[JFTAVMetalRenderer] Failed to create passthrough pipeline: %@", error);
        }
    }

    // Brightness/Contrast pipeline
    id<MTLFunction> brightnessContrastFrag = [library newFunctionWithName:@"brightnessContrastFragment"];
    if (brightnessContrastFrag) {
        pipelineDescriptor.fragmentFunction = brightnessContrastFrag;
        _brightnessContrastPipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    }

    // Saturation pipeline
    id<MTLFunction> saturationFrag = [library newFunctionWithName:@"saturationFragment"];
    if (saturationFrag) {
        pipelineDescriptor.fragmentFunction = saturationFrag;
        _saturationPipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    }

    // Dissolve transition pipeline
    id<MTLFunction> dissolveFrag = [library newFunctionWithName:@"dissolveFragment"];
    if (dissolveFrag) {
        pipelineDescriptor.fragmentFunction = dissolveFrag;
        _dissolvePipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    }
}

- (void)setupFallbackPipelines {
    // Use CIContext as fallback when Metal shaders are not available
    NSLog(@"[JFTAVMetalRenderer] Using CIContext fallback mode");
}

- (id<MTLTexture>)createTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                    pixelFormat:(MTLPixelFormat)pixelFormat
                                     planeIndex:(size_t)planeIndex {
    if (!pixelBuffer) return nil;

    size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex);
    size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex);

    CVMetalTextureRef textureRef = NULL;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                 _textureCache,
                                                                 pixelBuffer,
                                                                 nil,
                                                                 pixelFormat,
                                                                 width,
                                                                 height,
                                                                 planeIndex,
                                                                 &textureRef);

    if (status != kCVReturnSuccess || !textureRef) {
        NSLog(@"[JFTAVMetalRenderer] Failed to create texture from pixel buffer: %d", status);
        return nil;
    }

    id<MTLTexture> texture = CVMetalTextureGetTexture(textureRef);
    CFRelease(textureRef);

    return texture;
}

- (BOOL)renderPixelBuffer:(CVPixelBufferRef)sourcePixelBuffer
       toDestinationBuffer:(CVPixelBufferRef)destinationPixelBuffer
                filterType:(JFTAVMetalFilterType)filterType
                parameters:(NSDictionary *)parameters
                 transform:(CGAffineTransform)transform {

    if (!sourcePixelBuffer || !destinationPixelBuffer) {
        NSLog(@"[JFTAVMetalRenderer] Source or destination buffer is NULL");
        return NO;
    }

    @autoreleasepool {
        // Create textures from pixel buffers
        id<MTLTexture> sourceTexture = [self createTextureFromPixelBuffer:sourcePixelBuffer
                                                              pixelFormat:MTLPixelFormatBGRA8Unorm
                                                               planeIndex:0];

        id<MTLTexture> destinationTexture = [self createTextureFromPixelBuffer:destinationPixelBuffer
                                                                    pixelFormat:MTLPixelFormatBGRA8Unorm
                                                                     planeIndex:0];

        if (!sourceTexture || !destinationTexture) {
            return NO;
        }

        // Create command buffer
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = @"JFTAVMetalRenderer.Render";

        // Create render pass descriptor
        MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture;
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

        // Create render command encoder
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"JFTAVMetalRenderer.RenderEncoder";

        // Select pipeline based on filter type
        id<MTLRenderPipelineState> pipeline = [self pipelineForFilterType:filterType];
        if (!pipeline) {
            NSLog(@"[JFTAVMetalRenderer] Pipeline not available for filter type %lu", (unsigned long)filterType);
            [renderEncoder endEncoding];
            return NO;
        }

        [renderEncoder setRenderPipelineState:pipeline];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:sourceTexture atIndex:0];

        // Set filter parameters
        if (filterType == JFTAVMetalFilterTypeBrightness || filterType == JFTAVMetalFilterTypeContrast) {
            float brightness = [parameters[@"brightness"] floatValue];
            float contrast = [parameters[@"contrast"] floatValue] ?: 1.0f;
            float params[2] = {brightness, contrast};
            [renderEncoder setFragmentBytes:params length:sizeof(params) atIndex:0];
        } else if (filterType == JFTAVMetalFilterTypeSaturation) {
            float saturation = [parameters[@"saturation"] floatValue] ?: 1.0f;
            [renderEncoder setFragmentBytes:&saturation length:sizeof(saturation) atIndex:0];
        }

        // Draw full-screen quad
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [renderEncoder endEncoding];

        // Commit command buffer
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        return commandBuffer.status == MTLCommandBufferStatusCompleted;
    }
}

- (BOOL)renderTransitionWithForeground:(CVPixelBufferRef)foregroundBuffer
                            background:(CVPixelBufferRef)backgroundBuffer
                         toDestination:(CVPixelBufferRef)destinationBuffer
                              progress:(float)progress
                   foregroundTransform:(CGAffineTransform)foregroundTransform
                   backgroundTransform:(CGAffineTransform)backgroundTransform {

    if (!foregroundBuffer || !backgroundBuffer || !destinationBuffer) {
        NSLog(@"[JFTAVMetalRenderer] One or more buffers are NULL for transition");
        return NO;
    }

    @autoreleasepool {
        // Create textures
        id<MTLTexture> foregroundTexture = [self createTextureFromPixelBuffer:foregroundBuffer
                                                                   pixelFormat:MTLPixelFormatBGRA8Unorm
                                                                    planeIndex:0];

        id<MTLTexture> backgroundTexture = [self createTextureFromPixelBuffer:backgroundBuffer
                                                                   pixelFormat:MTLPixelFormatBGRA8Unorm
                                                                    planeIndex:0];

        id<MTLTexture> destinationTexture = [self createTextureFromPixelBuffer:destinationBuffer
                                                                    pixelFormat:MTLPixelFormatBGRA8Unorm
                                                                     planeIndex:0];

        if (!foregroundTexture || !backgroundTexture || !destinationTexture) {
            return NO;
        }

        // Create command buffer
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = @"JFTAVMetalRenderer.Transition";

        // Create render pass
        MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture;
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;

        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

        if (!_dissolvePipeline) {
            // Fallback to simple blend if dissolve pipeline not available
            _dissolvePipeline = _passthroughPipeline;
        }

        [renderEncoder setRenderPipelineState:_dissolvePipeline];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:foregroundTexture atIndex:0];
        [renderEncoder setFragmentTexture:backgroundTexture atIndex:1];
        [renderEncoder setFragmentBytes:&progress length:sizeof(progress) atIndex:0];

        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [renderEncoder endEncoding];

        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        return commandBuffer.status == MTLCommandBufferStatusCompleted;
    }
}

- (id<MTLRenderPipelineState>)pipelineForFilterType:(JFTAVMetalFilterType)filterType {
    switch (filterType) {
        case JFTAVMetalFilterTypePassthrough:
            return _passthroughPipeline;
        case JFTAVMetalFilterTypeBrightness:
        case JFTAVMetalFilterTypeContrast:
            return _brightnessContrastPipeline ?: _passthroughPipeline;
        case JFTAVMetalFilterTypeSaturation:
            return _saturationPipeline ?: _passthroughPipeline;
        case JFTAVMetalFilterTypeColorLUT:
            return _lutPipeline ?: _passthroughPipeline;
        case JFTAVMetalFilterTypeDissolve:
            return _dissolvePipeline ?: _passthroughPipeline;
        default:
            return _passthroughPipeline;
    }
}

- (void)clearCaches {
    @autoreleasepool {
        if (_textureCache) {
            CVMetalTextureCacheFlush(_textureCache, 0);
        }
    }
}

- (void)waitUntilCompleted {
    // Wait for any pending command buffers
    if (_currentCommandBuffer) {
        [_currentCommandBuffer waitUntilCompleted];
        _currentCommandBuffer = nil;
    }
}

@end
