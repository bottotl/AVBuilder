//
//  JFTAVCustomVideoCompositor.m
//  JFTAVEditor
//
//  Created by jft0m on 2017/7/13.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVCustomVideoCompositor.h"
#import "JFTAVCustomVideoCompositionInstruction.h"
#import <ImageIO/ImageIO.h>
#import "JFTDissolveTransition.h"
#import "Metal/JFTAVMetalRenderer.h"
#import "Metal/JFTAVMetalFilterAdapter.h"

@interface JFTAVCustomVideoCompositor ()
{
    BOOL                                _isMemoryWaning;
    BOOL								_shouldCancelAllRequests;
    BOOL								_renderContextDidChange;
    dispatch_queue_t					_renderingQueue;
    dispatch_queue_t					_renderContextQueue;
    AVVideoCompositionRenderContext*	_renderContext;
    CVPixelBufferRef					_previousBuffer;
    CIContext*                          _ciContext;
    JFTAVMetalRenderer*                 _metalRenderer;
    BOOL                                _useMetalRendering;
//    CGColorSpaceRef                     _rgbColorSpace;
}
@property (nonatomic, strong) JFTDissolveTransition *dissolveTransition;
@end

@implementation JFTAVCustomVideoCompositor
#pragma mark - AVVideoCompositing protocol

- (id)init
{
    self = [super init];
    if (self)
    {
        _isMemoryWaning = NO;
        _renderingQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.renderingqueue", DISPATCH_QUEUE_SERIAL);
        _renderContextQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
        _renderContextDidChange = NO;

        // Try to use Metal renderer first (better memory management)
        _metalRenderer = [[JFTAVMetalRenderer alloc] initWithDevice:nil];
        _useMetalRendering = (_metalRenderer != nil);

        if (_useMetalRendering) {
            NSLog(@"[JFTAVCustomVideoCompositor] Metal renderer initialized successfully");
        } else {
            NSLog(@"[JFTAVCustomVideoCompositor] Metal initialization failed, using CIContext fallback");
        }

        // Always initialize CIContext as fallback, even when Metal is available
        // This ensures we can fallback gracefully if Metal rendering fails at runtime
        EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _ciContext = [CIContext contextWithEAGLContext:eaglContext options:@{ kCIContextWorkingColorSpace : [NSNull null] } ];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarningNotification) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    _renderingQueue = nil;
    _renderContextQueue = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarningNotification {
    _isMemoryWaning = YES;

    // Clear Metal texture caches immediately on memory warning
    if (_useMetalRendering && _metalRenderer) {
        [_metalRenderer clearCaches];
        [_metalRenderer waitUntilCompleted];
    }

    NSLog(@"[JFTAVCustomVideoCompositor] Memory warning received, caches cleared");
}


//
//- (void)deleteBuffers {
//    if ( _rgbColorSpace ) {
//        CFRelease( _rgbColorSpace );
//        _rgbColorSpace = NULL;
//    }
//}



- (NSDictionary *)sourcePixelBufferAttributes
{
    // Always use BGRA format for compatibility with both Metal and CIContext
    // CIContext cannot write to YUV formats, so we must use BGRA
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    // Always use BGRA format for compatibility with both Metal and CIContext
    // CIContext cannot write to YUV formats, so we must use BGRA
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA],
              (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
    dispatch_sync(_renderContextQueue, ^() {
        _renderContext = newRenderContext;
        _renderContextDidChange = YES;
    });
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
    @autoreleasepool {
        dispatch_async(_renderingQueue,^() {
            @autoreleasepool {
                if (_isMemoryWaning) {
                    // Instead of sleeping, wait for GPU to complete and clear caches
                    if (_useMetalRendering && _metalRenderer) {
                        [_metalRenderer waitUntilCompleted];
                        [_metalRenderer clearCaches];
                    }
                    // Small delay to let memory settle
                    usleep(100000); // 100ms instead of 1 second
                    _isMemoryWaning = NO;
                }
                // Check if all pending requests have been cancelled
                if (_shouldCancelAllRequests) {
                    [request finishCancelledRequest];
                } else {
                    [self finishCompositionRequest:request];
                }
            }
        });
    }
}

- (void)finishCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
    if (!self.dissolveTransition) {
        self.dissolveTransition = [JFTDissolveTransition new];
    }
    NSError *err = nil;
    // Get the next rendererd pixel buffer
    JFTAVCustomVideoCompositionInstruction *instruction = request.videoCompositionInstruction;
    CVPixelBufferRef resultPixels = NULL;
    if (!instruction.transitionInstruction) {
        resultPixels = [self finishPassthroughCompositionRequest:request error:&err];
    } else {
        resultPixels = [self finishTweeningCompositionRequest:request error:&err];
    }
    if (resultPixels) {
        [request finishWithComposedVideoFrame:resultPixels];
        CVPixelBufferRelease(resultPixels);
    } else {
        [request finishWithError:err];
    }
    
}

- (CVPixelBufferRef)finishPassthroughCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut {
    @autoreleasepool {
        JFTAVCustomVideoCompositionInstruction *instruction = request.videoCompositionInstruction;
        JFTAVCustomVideoCompositionLayerInstruction *simpleLayerInstruction = instruction.simpleLayerInstructions.firstObject;
        CGSize renderSize = _renderContext.size;
        CVPixelBufferRef pixelBuffer = [_renderContext newPixelBuffer];

        if (!pixelBuffer) {
            *errOut = [NSError errorWithDomain:@"finishPassthroughCompositionRequest"
                                          code:1001
                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to allocate pixel buffer"}];
            return nil;
        }

        if (!request.sourceTrackIDs.count) {
            NSLog(@"request.sourceTrackIDs.count does not exit");
            // Render black frame - works for both Metal and CIContext
            if (_useMetalRendering && _metalRenderer) {
                // Metal will automatically clear to black
                return pixelBuffer;
            } else {
                CIImage *emptyImage = [CIImage imageWithColor:[CIColor colorWithCGColor:[UIColor blackColor].CGColor]];
                emptyImage = [emptyImage imageByCroppingToRect:CGRectMake(0, 0, renderSize.width, renderSize.height)];
                [_ciContext render:emptyImage toCVPixelBuffer:pixelBuffer];
                return pixelBuffer;
            }
        }

        CMPersistentTrackID trackID = simpleLayerInstruction ? simpleLayerInstruction.trackID : request.sourceTrackIDs[0].intValue;
        CVPixelBufferRef sourcePixels = [request sourceFrameByTrackID:trackID];

        if (!sourcePixels) {
            CVPixelBufferRelease(pixelBuffer);
            *errOut = [NSError errorWithDomain:@"finishPassthroughCompositionRequest"
                                          code:1002
                                      userInfo:@{NSLocalizedDescriptionKey: @"Source pixel buffer is NULL"}];
            return nil;
        }

        // Use Metal rendering if available
        if (_useMetalRendering && _metalRenderer) {
            CIFilter *filter = simpleLayerInstruction.videoItem.filter;
            CGAffineTransform transform = simpleLayerInstruction ? simpleLayerInstruction.transform : CGAffineTransformIdentity;

            // Metal renderer doesn't support transforms yet, so fall back to CIContext if transform is not identity
            // TODO: Implement transform support in Metal shaders
            BOOL needsTransform = !CGAffineTransformIsIdentity(transform);

            if (needsTransform) {
                // Use CIContext for transforms (handles rotation correctly)
                [self renderWithCIContext:sourcePixels
                                  toBuffer:pixelBuffer
                                    filter:filter
                                 transform:transform];
                return pixelBuffer;
            }

            // Check if we can render this filter with Metal
            JFTAVMetalFilterType filterType = JFTAVMetalFilterTypePassthrough;
            NSDictionary *filterParams = nil;

            if (filter && [JFTAVMetalFilterAdapter canRenderFilterWithMetal:filter]) {
                [JFTAVMetalFilterAdapter convertFilter:filter toMetalFilterType:&filterType parameters:&filterParams];
            }

            // Render with Metal (only when no transform needed)
            BOOL success = [_metalRenderer renderPixelBuffer:sourcePixels
                                         toDestinationBuffer:pixelBuffer
                                                  filterType:filterType
                                                  parameters:filterParams
                                                   transform:transform];

            if (!success) {
                NSLog(@"[JFTAVCustomVideoCompositor] Metal rendering failed, falling back to CIContext");
                // Fallback to CIContext on failure
                [self renderWithCIContext:sourcePixels
                                  toBuffer:pixelBuffer
                                    filter:filter
                                 transform:transform];
            }

            return pixelBuffer;
        } else {
            // CIContext path (original implementation)
            CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:sourcePixels];
            if (simpleLayerInstruction) {
                sourceImage = [sourceImage imageByApplyingTransform:[self transformFix:simpleLayerInstruction.transform extent:sourceImage.extent]];
            }

            if (simpleLayerInstruction.videoItem.filter) {
                [simpleLayerInstruction.videoItem.filter setValue:sourceImage forKey:kCIInputImageKey];
                sourceImage = simpleLayerInstruction.videoItem.filter.outputImage;
            }

            [_ciContext render:sourceImage toCVPixelBuffer:pixelBuffer];
            sourceImage = nil;

            if (!pixelBuffer) {
                *errOut = [NSError errorWithDomain:@"finishPassthroughCompositionRequest error unknow"
                                              code:1000
                                          userInfo:nil];
            }
            return pixelBuffer;
        }
    }
}

// Helper method for CIContext fallback rendering
- (void)renderWithCIContext:(CVPixelBufferRef)sourceBuffer
                    toBuffer:(CVPixelBufferRef)destBuffer
                      filter:(CIFilter *)filter
                   transform:(CGAffineTransform)transform {
    @autoreleasepool {
        CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:sourceBuffer];

        if (!CGAffineTransformIsIdentity(transform)) {
            sourceImage = [sourceImage imageByApplyingTransform:[self transformFix:transform extent:sourceImage.extent]];
        }

        if (filter) {
            [filter setValue:sourceImage forKey:kCIInputImageKey];
            sourceImage = filter.outputImage;
        }

        if (!_ciContext) {
            // Create CIContext if not available
            EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
            _ciContext = [CIContext contextWithEAGLContext:eaglContext options:@{ kCIContextWorkingColorSpace : [NSNull null] }];
        }

        [_ciContext render:sourceImage toCVPixelBuffer:destBuffer];
        sourceImage = nil;
    }
}


- (CGAffineTransform)transformFix:(CGAffineTransform)transform extent:(CGRect)extent {
    CGRect rect = CGRectApplyAffineTransform(extent, transform);
    CGAffineTransform t = CGAffineTransformScale(CGAffineTransformIdentity, 1, -1);
    t = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(0, extent.size.height));
    t = CGAffineTransformConcat(t, transform);
    t = CGAffineTransformConcat(t, CGAffineTransformScale(CGAffineTransformIdentity, 1, -1));
    t = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(0, rect.size.height));
    return t;
}

- (CVPixelBufferRef)finishTweeningCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut {
    @autoreleasepool {
        JFTAVCustomVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;
        JFTAVCustomVideoCompositionTransitionInstruction *transitionIns = currentInstruction.transitionInstruction;

        NSParameterAssert(currentInstruction);
        NSParameterAssert(currentInstruction.transitionInstruction);
        NSParameterAssert(transitionIns.forgroundTrackID != kCMPersistentTrackID_Invalid);
        NSParameterAssert(transitionIns.backgroundTrackID != kCMPersistentTrackID_Invalid);

        CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:transitionIns.forgroundTrackID];
        CVPixelBufferRef backgroundSourceBuffer = [request sourceFrameByTrackID:transitionIns.backgroundTrackID];

        if (!foregroundSourceBuffer || !backgroundSourceBuffer) {
            *errOut = [NSError errorWithDomain:@"finishTweeningCompositionRequest"
                                          code:1003
                                      userInfo:@{NSLocalizedDescriptionKey: @"Foreground or background buffer is NULL"}];
            return nil;
        }

        CVPixelBufferRef dstPixels = [_renderContext newPixelBuffer];
        if (!dstPixels) {
            *errOut = [NSError errorWithDomain:@"finishTweeningCompositionRequest"
                                          code:1004
                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to allocate destination buffer"}];
            return nil;
        }

        // Calculate transition progress
        float tweenFactor = factorForTimeInRange(request.compositionTime, request.videoCompositionInstruction.timeRange);

        JFTAVCustomVideoCompositionLayerInstruction *forLayerIns = currentInstruction.simpleLayerInstructions[0];
        JFTAVCustomVideoCompositionLayerInstruction *backLayerIns = currentInstruction.simpleLayerInstructions[1];

        CGAffineTransform foregroundTransform = forLayerIns ? forLayerIns.transform : CGAffineTransformIdentity;
        CGAffineTransform backgroundTransform = backLayerIns ? backLayerIns.transform : CGAffineTransformIdentity;

        // Use Metal rendering for transitions if available
        if (_useMetalRendering && _metalRenderer) {
            // Metal renderer doesn't support transforms yet, so fall back to CIContext if any transform is not identity
            BOOL needsTransform = !CGAffineTransformIsIdentity(foregroundTransform) || !CGAffineTransformIsIdentity(backgroundTransform);

            if (needsTransform) {
                // Use CIContext for transforms (handles rotation correctly)
                [self renderTransitionWithCIContext:foregroundSourceBuffer
                                         background:backgroundSourceBuffer
                                       toDestination:dstPixels
                                            progress:tweenFactor
                                  foregroundLayerIns:forLayerIns
                                  backgroundLayerIns:backLayerIns];
                return dstPixels;
            }

            BOOL success = [_metalRenderer renderTransitionWithForeground:foregroundSourceBuffer
                                                               background:backgroundSourceBuffer
                                                            toDestination:dstPixels
                                                                 progress:tweenFactor
                                                      foregroundTransform:foregroundTransform
                                                      backgroundTransform:backgroundTransform];

            if (!success) {
                NSLog(@"[JFTAVCustomVideoCompositor] Metal transition failed, falling back to CIContext");
                // Fallback to CIContext
                [self renderTransitionWithCIContext:foregroundSourceBuffer
                                         background:backgroundSourceBuffer
                                       toDestination:dstPixels
                                            progress:tweenFactor
                                  foregroundLayerIns:forLayerIns
                                  backgroundLayerIns:backLayerIns];
            }

            return dstPixels;
        } else {
            // Original CIContext path
            [self renderTransitionWithCIContext:foregroundSourceBuffer
                                     background:backgroundSourceBuffer
                                   toDestination:dstPixels
                                        progress:tweenFactor
                              foregroundLayerIns:forLayerIns
                              backgroundLayerIns:backLayerIns];

            if (!dstPixels) {
                *errOut = [NSError errorWithDomain:@"finishTweeningCompositionRequest error unknow"
                                              code:1000
                                          userInfo:nil];
            }

            return dstPixels;
        }
    }
}

// Helper method for CIContext transition rendering
- (void)renderTransitionWithCIContext:(CVPixelBufferRef)foregroundBuffer
                           background:(CVPixelBufferRef)backgroundBuffer
                        toDestination:(CVPixelBufferRef)destinationBuffer
                             progress:(float)progress
                   foregroundLayerIns:(JFTAVCustomVideoCompositionLayerInstruction *)forLayerIns
                   backgroundLayerIns:(JFTAVCustomVideoCompositionLayerInstruction *)backLayerIns {
    @autoreleasepool {
        CIImage *forImage = [CIImage imageWithCVPixelBuffer:foregroundBuffer];
        CIImage *backImage = [CIImage imageWithCVPixelBuffer:backgroundBuffer];

        // Apply transforms and filters
        if (forLayerIns) {
            forImage = [forImage imageByApplyingTransform:[self transformFix:forLayerIns.transform extent:forImage.extent]];
        }
        if (forLayerIns.videoItem.filter) {
            [forLayerIns.videoItem.filter setValue:forImage forKey:kCIInputImageKey];
            forImage = forLayerIns.videoItem.filter.outputImage;
        }

        if (backImage) {
            backImage = [backImage imageByApplyingTransform:[self transformFix:backLayerIns.transform extent:backImage.extent]];
        }
        if (backLayerIns.videoItem.filter) {
            [backLayerIns.videoItem.filter setValue:backImage forKey:kCIInputImageKey];
            backImage = backLayerIns.videoItem.filter.outputImage;
        }

        // Apply transition
        if (!self.dissolveTransition) {
            self.dissolveTransition = [JFTDissolveTransition new];
        }

        self.dissolveTransition.forgroundImage = forImage;
        self.dissolveTransition.backgroundImage = backImage;
        self.dissolveTransition.inputTime = [NSNumber numberWithFloat:progress];
        CIImage *desImage = self.dissolveTransition.outputImage;

        if (!_ciContext) {
            EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
            _ciContext = [CIContext contextWithEAGLContext:eaglContext options:@{ kCIContextWorkingColorSpace : [NSNull null] }];
        }

        [_ciContext render:desImage toCVPixelBuffer:destinationBuffer];

        // Clear references
        forImage = nil;
        backImage = nil;
        desImage = nil;
    }
}

- (void)cancelAllPendingVideoCompositionRequests
{
    // pending requests will call finishCancelledRequest, those already rendering will call finishWithComposedVideoFrame
    _shouldCancelAllRequests = YES;
    
    dispatch_barrier_async(_renderingQueue, ^() {
        // start accepting requests again
        _shouldCancelAllRequests = NO;
    });
}

#pragma mark - Utilities

static Float64 factorForTimeInRange(CMTime time, CMTimeRange range) /* 0.0 -> 1.0 */
{
    CMTime elapsed = CMTimeSubtract(time, range.start);
    return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
}

@end
