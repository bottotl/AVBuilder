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

@interface JFTAVCustomVideoCompositor ()
{
    BOOL								_shouldCancelAllRequests;
    BOOL								_renderContextDidChange;
    dispatch_queue_t					_renderingQueue;
    dispatch_queue_t					_renderContextQueue;
    AVVideoCompositionRenderContext*	_renderContext;
    CVPixelBufferRef					_previousBuffer;
    CIContext*                          _ciContext;
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
        _renderingQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.renderingqueue", DISPATCH_QUEUE_SERIAL);
        _renderContextQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
        _renderContextDidChange = NO;
//        _rgbColorSpace = CGColorSpaceCreateDeviceRGB();
        EAGLContext *eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _ciContext = [CIContext contextWithEAGLContext:eaglContext options:@{ kCIContextWorkingColorSpace : [NSNull null] } ];
    }
    return self;
}

-(void)dealloc {
    _renderingQueue = nil;
    _renderContextQueue = nil;
//    [self deleteBuffers];
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
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
              (NSString*)kCVPixelBufferOpenGLESCompatibilityKey : [NSNumber numberWithBool:YES]};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
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
            // Check if all pending requests have been cancelled
            if (_shouldCancelAllRequests) {
                [request finishCancelledRequest];
            } else {
//                CVPixelBufferRef photo = [request sourceFrameByTrackID:request.sourceTrackIDs[0].intValue];
//                if (photo) {
//                    [request finishWithComposedVideoFrame:photo];
//                } else {
//                    [request finishWithError:[NSError new]];
//                }
                [self finishCompositionRequest:request];
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
        if (!request.sourceTrackIDs.count) {
            NSLog(@"request.sourceTrackIDs.count does not exit");
            
            CIImage *emptyImage = [CIImage imageWithColor:[CIColor colorWithCGColor:[UIColor blackColor].CGColor]];
            emptyImage = [emptyImage imageByCroppingToRect:CGRectMake(0, 0, renderSize.width, renderSize.height)];
            [_ciContext render:emptyImage toCVPixelBuffer:pixelBuffer];
            
            return pixelBuffer;
        }
        CMPersistentTrackID trackID = simpleLayerInstruction?simpleLayerInstruction.trackID:request.sourceTrackIDs[0].intValue;
        CVPixelBufferRef sourcePixels = [request sourceFrameByTrackID:trackID];
        if (!sourcePixels) return nil;
        
        CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:sourcePixels];
        if (simpleLayerInstruction) {
            sourceImage = [sourceImage imageByApplyingTransform:[self transformFix:simpleLayerInstruction.transform extent:sourceImage.extent]];
        }
        
        if (simpleLayerInstruction.videoItem.filter) {
            [simpleLayerInstruction.videoItem.filter setValue:sourceImage forKey:kCIInputImageKey];
            sourceImage = simpleLayerInstruction.videoItem.filter.outputImage;
        }
        
        [_ciContext render:sourceImage toCVPixelBuffer:pixelBuffer];
        
        if (!pixelBuffer) {
            *errOut = [NSError errorWithDomain:@"finishPassthroughCompositionRequest error unknow"
                                                          code:1000
                                                      userInfo:nil];
        }
        return pixelBuffer;
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
    JFTAVCustomVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;
    JFTAVCustomVideoCompositionTransitionInstruction *transitionIns = currentInstruction.transitionInstruction;
    
    NSParameterAssert(currentInstruction);
    NSParameterAssert(currentInstruction.transitionInstruction);
    NSParameterAssert(transitionIns.forgroundTrackID != kCMPersistentTrackID_Invalid);
    NSParameterAssert(transitionIns.backgroundTrackID != kCMPersistentTrackID_Invalid);
    
    CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:transitionIns.forgroundTrackID];
    CVPixelBufferRef backgroundSourceBuffer = [request sourceFrameByTrackID:transitionIns.backgroundTrackID];
    
    CIImage *forImage = [CIImage imageWithCVPixelBuffer:foregroundSourceBuffer];
    CIImage *backImage = [CIImage imageWithCVPixelBuffer:backgroundSourceBuffer];
    
    /// 缩放 & 加滤镜
    JFTAVCustomVideoCompositionLayerInstruction *forLayerIns = currentInstruction.simpleLayerInstructions[0];
    if (forLayerIns) {
        forImage = [forImage imageByApplyingTransform:[self transformFix:forLayerIns.transform extent:forImage.extent]];
    }
    if (forLayerIns.videoItem.filter) {
        [forLayerIns.videoItem.filter setValue:forImage forKey:kCIInputImageKey];
        forImage = forLayerIns.videoItem.filter.outputImage;
    }
    
    JFTAVCustomVideoCompositionLayerInstruction *backLayerIns = currentInstruction.simpleLayerInstructions[1];
    if (backImage) {
        backImage = [backImage imageByApplyingTransform:[self transformFix:backLayerIns.transform extent:backImage.extent]];
    }
    if (backLayerIns.videoItem.filter) {
        [backLayerIns.videoItem.filter setValue:backImage forKey:kCIInputImageKey];
        backImage = backLayerIns.videoItem.filter.outputImage;
    }
    
    /// 加过场动画
    
    // tweenFactor indicates how far within that timeRange are we rendering this frame. This is normalized to vary between 0.0 and 1.0.
    // 0.0 indicates the time at first frame in that videoComposition timeRange
    // 1.0 indicates the time at last frame in that videoComposition timeRange
    float tweenFactor = factorForTimeInRange(request.compositionTime, request.videoCompositionInstruction.timeRange);
    
    self.dissolveTransition.forgroundImage = forImage;
    self.dissolveTransition.backgroundImage = backImage;
    self.dissolveTransition.inputTime = [NSNumber numberWithFloat:tweenFactor];
    CIImage *desImage = self.dissolveTransition.outputImage;
    
    CVPixelBufferRef dstPixels = [_renderContext newPixelBuffer];
    
    [_ciContext render:desImage toCVPixelBuffer:dstPixels];
    
    if (!dstPixels) {*errOut = [NSError errorWithDomain:@"finishTweeningCompositionRequest error unknow" code:1000 userInfo:nil];}
    
    return dstPixels;
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
