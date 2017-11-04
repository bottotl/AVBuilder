//
//  JFTAVBuilder.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/7.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVBuilder.h"
#import "JFTAVMediaItem+Private.h"
#import "JFTAVTimelineItem+Private.h"
#import "JFTAVVideoMediaItem.h"
#import "JFTAVMusicMediaItem.h"
#import "JFTAVSubtitlesItem.h"
#import "JFTAVOverlayItem.h"
#import "JFTAVAnimationMaker.h"
#import "JFTAVBuilderSettings+Private.h"
/// custom compositor
#import "JFTAVCustomVideoCompositor.h"
#import "JFTAVCustomVideoCompositionInstruction.h"
/// helper
#import "JFTAVSizeHelper.h"

#define VIDEO_SIZE CGSizeMake(540, 960)

@interface JFTAVBuilder ()

@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) AVMutableComposition        *composition;
@property (nonatomic, strong) AVMutableAudioMix           *audioMix;
@property (nonatomic, strong) AVMutableVideoComposition   *videoComposition;

@property (nonatomic, assign) JFTAVBuildStatus state;

@end

@implementation JFTAVBuilder

+ (instancetype)builderWithTimeLine:(JFTAVTimeLine *)timeLine {
    JFTAVBuilder *builder = [JFTAVBuilder new];
    builder.timeLine = timeLine;
    builder.state = JFTAVBuildStatusInit;
    JFTAVBuilderSettings *settings = [JFTAVBuilderSettings new];
    settings.frameDuration = CMTimeMake(1, 30);
    settings.preferredVideoSize = VIDEO_SIZE;
    builder.settings = settings;
    builder.error = nil;
    return builder;
}

- (void)buildTimeline {
    [self reset];
    [self buildComposition:nil];
}

- (void)reset {
    _composition = nil;
    _audioMix = nil;
    _videoComposition = nil;
    _error = nil;
    _state = JFTAVBuildStatusInit;
}

#pragma mark - Composition

- (void)buildComposition:(void (^)(AVMutableComposition *))completionBlock {
    if (self.state == JFTAVBuildStatusBuilding) {
        return;
    }
    self.state = JFTAVBuildStatusBuilding;
    dispatch_group_t dispatchGroupInner = dispatch_group_create();
    for (JFTAVVideoMediaItem *item in self.timeLine.videos) {
        [self loadMediaItem:item
          usingDispathGroup:dispatchGroupInner];
    }
    
    [self loadMediaItem:self.timeLine.music
      usingDispathGroup:dispatchGroupInner];
    
    dispatch_group_notify(dispatchGroupInner, dispatch_get_main_queue(), ^{
        if (self.error) {
            self.state = JFTAVBuildStatusFail;
            if (completionBlock) completionBlock(nil);
            return;
        }
        [self createAVCompositonWithLoadedTimeLine:self.timeLine
                                         completion:^(AVMutableComposition *composition,
                                                     AVMutableVideoComposition *videoComposition,
                                                     AVMutableAudioMix *audioMix) {
                                             self.composition = composition;
                                             self.videoComposition = videoComposition;
                                             self.audioMix = audioMix;
                                             self.state = JFTAVBuildStatusComplete;
                                             if (completionBlock) completionBlock(composition);
                                         }];
        
    });
}

- (void)loadMediaItem:(JFTAVMediaItem *)item
    usingDispathGroup:(dispatch_group_t)group {
    if (!item || self.error) return;
    dispatch_group_enter(group);
    NSLog(@"Entering item: %@", item);
    [item prepareWithCompletionBlock:^(JFTAVMediaItemStatus status) {
        if (status == JFTAVMediaItemStatusFailed) {
            NSLog(@"JFTAVVideoMediaItem prepare error");
            [self completeItemLoadWithError:@"JFTAVVideoMediaItem prepare error"];
        } else if (status == JFTAVMediaItemStatusLoaded) { }
        NSLog(@"Leaving item: %@", item);
        dispatch_group_leave(group);
    }];
}

- (void)completeItemLoadWithError:(NSString *)errorMessage {
    if (errorMessage.length && !self.error) {
        self.error = [NSError errorWithDomain:@"JFTAVBuilerErrorDomain"
                                         code:-44444
                                     userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
    }
}

/**
 调用前必须确保 timeLine 中的 asset 已经完成加载
 
 @param timeLine timeline
 @param completion completion
 */
- (void)createAVCompositonWithLoadedTimeLine:(JFTAVTimeLine *)timeLine
                                   completion:(void(^)(AVMutableComposition *composition,
                                                       AVMutableVideoComposition *videoComposition,
                                                       AVMutableAudioMix *audioMix))completion {
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *videoTrackA = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *videoTrackB = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVMutableCompositionTrack *audioTrackA = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *audioTrackB = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                      preferredTrackID:kCMPersistentTrackID_Invalid];
    
    NSArray *videoTracks = @[videoTrackA, videoTrackB];
    NSArray *audioTracks = @[audioTrackA, audioTrackB];
    
    CMTime cursorTime = kCMTimeZero;
    CMTime maxTime    = kCMTimeZero;///< 已经插入轨道中的视频的结束时间
    NSUInteger videoCount = timeLine.videos.count;
    if (videoCount == 0) {
        self.error = [NSError errorWithDomain:@"JFTAVBuilerErrorDomain"
                                         code:-44444
                                     userInfo:@{ NSLocalizedDescriptionKey: @"你好歹给我一个视频啊！"}];
        return completion(nil, nil, nil);
    }
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    NSMutableArray <JFTAVCustomVideoCompositionInstruction *> *instructions = @[].mutableCopy;
    JFTAVVideoMediaItemTransition *lastTransition = nil; /// transition to be added
    NSInteger audioCount = 0;
    for (int i = 0; i < videoCount; i++) {
        NSUInteger trackIndex = i % 2;
        AVMutableCompositionTrack *currentVideoTrack = videoTracks[trackIndex];
        AVMutableCompositionTrack *currentAudioTrack = audioTracks[trackIndex];
        JFTAVVideoMediaItem *item = timeLine.videos[i];
        item.videoTrackID = currentVideoTrack.trackID;
        item.audioTrackID = currentAudioTrack.trackID;
        
        AVAssetTrack *videoTrack = [item.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
        [currentVideoTrack insertTimeRange:item.timeRange
                                   ofTrack:videoTrack
                                    atTime:cursorTime
                                     error:nil];
        if (i == 0) {
            self.settings.videoSize = [JFTAVSizeHelper renderSizeWithAssetTrack:videoTrack andPerferedSize:self.settings.preferredVideoSize];
        }
        item.timeRangeInTimeline = CMTimeRangeMake(cursorTime, videoTrack.timeRange.duration);
        maxTime = CMTimeAdd(cursorTime, videoTrack.timeRange.duration);
        if (!item.muted && [item.asset tracksWithMediaType:AVMediaTypeAudio].count) {
            [currentAudioTrack insertTimeRange:item.timeRange
                                       ofTrack:[item.asset tracksWithMediaType:AVMediaTypeAudio].firstObject
                                        atTime:cursorTime
                                         error:nil];
            if (audioCount < 2) {
                audioCount ++;
            }
        }
        
        if (![self isTweeningTransition:lastTransition]) {///创建 passthrough instruction
            JFTAVCustomVideoCompositionInstruction *instruction = [JFTAVCustomVideoCompositionInstruction new];
            instruction.simpleLayerInstructions
            = @[[self createLayerInsWithVideoItem:item andTrackID:currentVideoTrack.trackID]];
            instruction.timeRange = CMTimeRangeMake(cursorTime, item.timeRange.duration);
            [instructions addObject:instruction];
            NSLog(@"add instruction:");
            [self logTimeRange:instruction.timeRange];
            
        } else {
            /// 把上一次设置的 Instruction 的时间缩短
            JFTAVCustomVideoCompositionInstruction *lastIns = instructions.lastObject;
            // 要做多长时间的过场动画
            CMTime lastTransitionDuration = CMTimeSubtract(CMTimeAdd(lastIns.timeRange.start, lastIns.timeRange.duration),
                                                           cursorTime);
            lastIns.timeRange = CMTimeRangeMake(lastIns.timeRange.start, CMTimeSubtract(lastIns.timeRange.duration, lastTransitionDuration));
            NSLog(@"change: Ins");
            [self logTimeRange:lastIns.timeRange];
            /// 创建渐变动画的 Instruction
            JFTAVCustomVideoCompositionInstruction *transitionIns = [JFTAVCustomVideoCompositionInstruction new];
            
            AVMutableCompositionTrack *lastVideoTrack = videoTracks[1 - trackIndex];
            JFTAVVideoMediaItem *lastItem = timeLine.videos[i - 1];
            transitionIns.transitionInstruction = [JFTAVCustomVideoCompositionTransitionInstruction new];
            // transition instruction
            transitionIns.transitionInstruction.forgroundTrackID = lastVideoTrack.trackID;
            transitionIns.transitionInstruction.backgroundTrackID = currentVideoTrack.trackID;
            // layer instruction
            JFTAVCustomVideoCompositionLayerInstruction *forlayerIns
            = [self createLayerInsWithVideoItem:lastItem andTrackID:lastVideoTrack.trackID];
            
            JFTAVCustomVideoCompositionLayerInstruction *backLayerIns
            = [self createLayerInsWithVideoItem:item andTrackID:currentVideoTrack.trackID];
            transitionIns.timeRange = CMTimeRangeMake(cursorTime, lastTransitionDuration);
            transitionIns.simpleLayerInstructions = @[forlayerIns, backLayerIns];
            [instructions addObject:transitionIns];
            NSLog(@"t: transitionIns");
            [self logTimeRange:transitionIns.timeRange];
            
            ///创建 passthrough instruction
            JFTAVCustomVideoCompositionInstruction *passthroughIns = [JFTAVCustomVideoCompositionInstruction new];
            passthroughIns.simpleLayerInstructions
            = @[[self createLayerInsWithVideoItem:item andTrackID:currentVideoTrack.trackID]];
            passthroughIns.timeRange = CMTimeRangeMake(CMTimeAdd(cursorTime, lastTransitionDuration),
                                                       CMTimeSubtract(item.timeRange.duration, lastTransitionDuration));
            [instructions addObject:passthroughIns];
            NSLog(@"t: passthroughIns");
            [self logTimeRange:passthroughIns.timeRange];
            
        }
        
        CMTime transitionDuration = kCMTimeZero;
        if (CMTIME_IS_VALID(item.transition.transitionDuration)) {
            transitionDuration = item.transition.transitionDuration;
        }
        
        // 让 transitionDuration 不要比前后两个视频的一半长度大
        if (i < (videoCount - 1)) {// 最后一段视频不用管
            CMTime halfForgroundVideoDuration = item.timeRange.duration;
            halfForgroundVideoDuration.timescale *= 2;
            CMTime halfBackgroundVideoDuration = timeLine.videos[i + 1].timeRange.duration;
            halfBackgroundVideoDuration.timescale *= 2;
            CMTime halfDuration = CMTimeMinimum(halfForgroundVideoDuration, halfBackgroundVideoDuration);
            if (CMTimeCompare(transitionDuration, halfDuration) == 1) {
                transitionDuration = halfDuration;
            }
        }
        
        cursorTime = CMTimeAdd(cursorTime, item.timeRange.duration);
        cursorTime = CMTimeSubtract(cursorTime, transitionDuration);
        
        NSLog(@"[cursorTime ] = %f", CMTimeGetSeconds(cursorTime));
        NSLog(@"[transitionDuration ] = %f", CMTimeGetSeconds(transitionDuration));
        lastTransition = item.transition;
    }
    
    NSLog(@"instructionsGuard:%@", @([self instructionsGuard:instructions withStartTime:kCMTimeZero andEndTime:composition.duration]));
    
    videoComposition.customVideoCompositorClass = [JFTAVCustomVideoCompositor class];
    videoComposition.instructions = instructions;
    videoComposition.frameDuration = self.settings.frameDuration;
    videoComposition.renderSize = self.settings.videoSize;
    
    /// mix audio and music
    AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
    
    NSMutableArray <AVMutableAudioMixInputParameters *> *inputParametersArray = @[].mutableCopy;
    
    NSMutableArray <AVMutableAudioMixInputParameters *> *audioParametersArray = @[].mutableCopy;
    AVMutableAudioMixInputParameters *audioParametersA = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrackA];
    AVMutableAudioMixInputParameters *audioParametersB = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:audioTrackB];
    [audioParametersArray addObjectsFromArray:@[audioParametersA, audioParametersB]];
    [inputParametersArray addObjectsFromArray:audioParametersArray];
    
    if (self.timeLine.music) {
        NSMutableArray <AVMutableCompositionTrack *>        *musicTracks     = @[].mutableCopy;
        NSMutableArray <AVMutableAudioMixInputParameters *> *musicParametersArray = @[].mutableCopy;
        
        CGFloat mixRate = self.timeLine.music.mixRate;
        {/// fix mix rate
            mixRate = (mixRate > 1 ? 1 : mixRate);
            mixRate = (mixRate < 0 ? 0 : mixRate);
        }
        CMTimeRange timeRange = self.timeLine.music.timeRange;
        {/// fix music timeRange. 让音乐不超过视频
            CMTime endTime = CMTimeAdd(timeRange.start, timeRange.duration);
            if (CMTimeCompare(endTime, maxTime) == 1) {
                timeRange = CMTimeRangeMake(timeRange.start,
                                            CMTimeSubtract(maxTime, timeRange.start));
            }
        }
        [[timeLine.music.asset tracksWithMediaType:AVMediaTypeAudio] enumerateObjectsUsingBlock:^(AVAssetTrack * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            AVMutableCompositionTrack *musicTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                             preferredTrackID:kCMPersistentTrackID_Invalid];
            [musicTrack insertTimeRange:timeRange
                                ofTrack:obj
                                 atTime:kCMTimeZero
                                  error:nil];
            timeLine.music.timeRangeInTimeline = timeRange;
            [musicTracks addObject:musicTrack];
            AVMutableAudioMixInputParameters *musicParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:musicTrack];
            [musicParameters setVolumeRampFromStartVolume:mixRate
                                              toEndVolume:mixRate
                                                timeRange:timeLine.music.timeRange];
            [musicParametersArray addObject:musicParameters];
        }];
        [audioParametersA setVolumeRampFromStartVolume:(1-mixRate)
                                           toEndVolume:(1-mixRate)
                                             timeRange:timeLine.music.timeRange];
        
        [audioParametersB setVolumeRampFromStartVolume:(1-mixRate)
                                           toEndVolume:(1-mixRate)
                                             timeRange:timeLine.music.timeRange];
        
        [inputParametersArray addObjectsFromArray:musicParametersArray];
    }
    
    audioMix.inputParameters = inputParametersArray;
    
    //    [instructions enumerateObjectsUsingBlock:^(JFTAVCustomVideoCompositionInstruction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    //        [self logTimeRange:obj.timeRange];
    //    }];
    
    /// 如果没有加过音频就把音频轨道都移除了
    if (audioCount == 0) {
        [composition removeTrack:audioTrackA];
        [composition removeTrack:audioTrackB];
        audioMix = nil;
    }
    
    if (completion) completion(composition,
                             videoComposition,
                             audioMix);
}


#pragma mark - Utilities
- (BOOL)isTweeningTransition:(JFTAVVideoMediaItemTransition *)transition {
    if (!transition) return NO;
    if (CMTIME_IS_VALID(transition.transitionDuration) && CMTimeCompare(transition.transitionDuration, kCMTimeZero) == 1) {
        return YES;
    }
    return NO;
}

/*
 For the first instruction in the array, timeRange.start must be less than or equal to the earliest time for which playback or other processing will be attempted
 (note that this will typically be kCMTimeZero). For subsequent instructions, timeRange.start must be equal to the prior instruction's end time. The end time of
 the last instruction must be greater than or equal to the latest time for which playback or other processing will be attempted (note that this will often be
 the duration of the asset with which the instance of AVVideoComposition is associated).
 */
- (BOOL)instructionsGuard:(NSArray <JFTAVCustomVideoCompositionInstruction *> *)instructions
            withStartTime:(CMTime)startTime
               andEndTime:(CMTime)endTime {
    
    /// first timeRange.start must not greater than startTime
    if (CMTimeCompare(instructions.firstObject.timeRange.start, startTime) == 1) {
        NSLog(@"first timeRange.start must not greater than startTime");
        return NO;
    }
    
    if (CMTimeCompare(CMTimeAdd(instructions.lastObject.timeRange.start,
                                instructions.lastObject.timeRange.duration), endTime) < 0) {
        NSLog(@"last instruction must be greater than or equal to the latest time for which playback or other processing will be attempted");
        return NO;
    }
    
    __block CMTimeRange lastTimeRange = kCMTimeRangeInvalid;
    __block BOOL flag = YES;
    [instructions enumerateObjectsUsingBlock:^(JFTAVCustomVideoCompositionInstruction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"timeRang[%lu]", (unsigned long)idx);
        [self logTimeRange:obj.timeRange];
        if (!CMTIMERANGE_IS_VALID(obj.timeRange)) {
            *stop = YES;
            flag = NO;
            NSLog(@"timeRange not valid at index: %lu", (unsigned long)idx);
        }
        if (CMTIMERANGE_IS_VALID(lastTimeRange)) {
            CMTime endtime = CMTimeAdd(lastTimeRange.start, lastTimeRange.duration);
            if (CMTimeCompare(endtime, obj.timeRange.start) != 0) {
                *stop = YES;
                flag = NO;
                NSLog(@"timeRange not valid at index: %lu \n error: For subsequent instructions, timeRange.start must be equal to the prior instruction's end time", (unsigned long)idx);
            }
        }
        lastTimeRange = obj.timeRange;
    }];
    return flag;
}

- (void)logTimeRange:(CMTimeRange)timeRange {
    NSLog(@"start:%f \n end:%f",CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(CMTimeAdd(timeRange.duration, timeRange.start)));
}

- (JFTAVCustomVideoCompositionLayerInstruction *)createLayerInsWithVideoItem:(JFTAVVideoMediaItem *)item andTrackID:(CMPersistentTrackID)trackID {
    AVAssetTrack *track = [item.asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    CGAffineTransform transform = CGAffineTransformConcat([JFTAVSizeHelper createPreferredTransformWithVideoTrack:track],
                                                          [JFTAVSizeHelper scaleTransformWithTrack:track andRenderSize:self.settings.videoSize]);
    return [[JFTAVCustomVideoCompositionLayerInstruction alloc] initWithTrackID:trackID
                                                                      transform:transform
                                                                      videoItem:item];
}

@end

@implementation JFTAVBuilderSettings

@end
