//
//  JFTAVBuilder+Play.m
//  Pods
//
//  Created by jft0m on 2017/7/21.
//
//

#import "JFTAVBuilder+Play.h"
#import "JFTAVVideoMediaItem.h"
#import "JFTAVSubtitlesItem.h"
#import "JFTAVAnimationMaker.h"
#import "JFTAVOverlayItem.h"
#import "JFTAVBuilder.h"

@implementation JFTAVBuilder (Play)
#pragma mark - video composition

- (AVVideoCompositionCoreAnimationTool *)makeAnimationTool {
    return [self makeAnimationTool:CGRectMake(0, 0, self.videoComposition.renderSize.width, self.videoComposition.renderSize.height)];
}

- (AVVideoCompositionCoreAnimationTool *)makeAnimationTool:(CGRect)renderFrame {
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = videoLayer.frame = renderFrame;
    [parentLayer addSublayer:videoLayer];
    
    [parentLayer addSublayer:[self createAnimationLayerWithTimeLine:self.timeLine andSize:self.videoComposition.renderSize isExport:YES]];
    
    AVVideoCompositionCoreAnimationTool *animationTool = [AVVideoCompositionCoreAnimationTool
                                                          videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer
                                                          inLayer:parentLayer];
    return animationTool;
}

- (CALayer *)createAnimationLayer {
    return [self createAnimationLayerWithTimeLine:self.timeLine andSize:self.videoComposition.renderSize isExport:NO];
}

- (CALayer *)createAnimationLayerWithTimeLine:(JFTAVTimeLine *)timeLine andSize:(CGSize)videoSize isExport:(BOOL)isExport {
    CGRect frame = CGRectMake(0, 0, videoSize.width, videoSize.height);
    CALayer *layer = [CALayer layer];
    layer.frame = frame;
    CMTime startTime, endTime; // the start time of time line
    
    startTime = timeLine.videos.firstObject.timeRangeInTimeline.start;
    
    if (CMTIMERANGE_IS_VALID(timeLine.videos.lastObject.timeRange)) {
        endTime = CMTimeAdd(timeLine.videos.lastObject.timeRangeInTimeline.start,
                            timeLine.videos.lastObject.timeRange.duration);
    } else {
        endTime = CMTimeAdd(timeLine.videos.lastObject.timeRangeInTimeline.start,
                            timeLine.videos.lastObject.asset.duration);
    }
//    NSLog(@"animation start time = %f", CMTimeGetSeconds(startTime));
//    NSLog(@"animation end time = %f", CMTimeGetSeconds(endTime));
    
    if (timeLine.subtitle) {
        JFTAVSubtitlesItem *subtitlesItem = timeLine.subtitle;
        CALayer *subtitlesLayer = [JFTAVAnimationMaker createTextAnimationLayerWithText:subtitlesItem.title
                                                                                andType:JFTAVTextAnimationFadeInAndOut
                                                                              withFrame:frame
                                                                            andDuration:CMTimeSubtract(endTime, startTime)];
        [layer addSublayer:subtitlesLayer];
    }
    
    if (timeLine.nameOverlay) {
        JFTAVOverlayItem *overlayItem = timeLine.nameOverlay;
        CALayer *overlayLayer = [JFTAVAnimationMaker createNameOverlayLayerWithName:overlayItem.nameText
                                                                           andImage:overlayItem.overlayImage
                                                                            andType:JFTAVNameOverlayAnimationNone
                                                                           withSize:overlayItem.size
                                                                        andDuration:CMTimeSubtract(endTime, startTime)];
//        overlayLayer.backgroundColor = [UIColor redColor].CGColor;
        if (isExport) {
            overlayLayer.frame = CGRectMake(videoSize.width * overlayItem.rightBottomPosition.x - overlayItem.size.width,
                                            videoSize.height * (1 - overlayItem.rightBottomPosition.y),
                                            overlayItem.size.width ,
                                            overlayItem.size.height);
        } else {
            overlayLayer.frame = CGRectMake(videoSize.width * overlayItem.rightBottomPosition.x - overlayItem.size.width,
                                            videoSize.height * overlayItem.rightBottomPosition.y - overlayItem.size.height,
                                            overlayItem.size.width ,
                                            overlayItem.size.height);
        }
        
        [layer addSublayer:overlayLayer];
    }
    
    return layer;
}

+ (CGAffineTransform)scaleTransformMaker:(CGRect)videoRect andPlayerRect:(CGRect)PlayerRect {
    CGFloat rate = MIN(PlayerRect.size.width / videoRect.size.width, PlayerRect.size.height / videoRect.size.height);
    return CGAffineTransformMakeScale(rate, rate);
}

@end
