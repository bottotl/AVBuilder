//
//  JFTAVCustomVideoCompositionInstruction.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/10.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "JFTAVVideoMediaItem.h"

NS_ASSUME_NONNULL_BEGIN

// 简单支持一下旋转
@interface JFTAVCustomVideoCompositionLayerInstruction : NSObject
@property (nonatomic, assign) CMPersistentTrackID trackID;
@property (nonatomic, assign) CGAffineTransform transform;
@property (nonatomic, strong, nullable) JFTAVVideoMediaItem *videoItem;

- (instancetype)initWithTrackID:(CMPersistentTrackID)trackID
                      transform:(CGAffineTransform)transform
                      videoItem:(JFTAVVideoMediaItem *)videoItem;

@end

/**
 必须给两个 trackID
 */
@interface JFTAVCustomVideoCompositionTransitionInstruction : NSObject
@property (nonatomic, assign) CMPersistentTrackID forgroundTrackID;
@property (nonatomic, assign) CMPersistentTrackID backgroundTrackID;
@end

@interface JFTAVCustomVideoCompositionInstruction : NSObject <AVVideoCompositionInstruction>

@property (nonatomic, assign) CMTimeRange timeRange;
@property (nonatomic, assign) BOOL enablePostProcessing;
@property (nonatomic, assign) BOOL containsTweening;
@property (nonatomic, assign, nullable) NSArray<NSValue *> *requiredSourceTrackIDs;
@property (nonatomic, assign) CMPersistentTrackID passthroughTrackID;

@property (nonatomic, strong, nullable) NSArray <JFTAVCustomVideoCompositionLayerInstruction *> *simpleLayerInstructions;
@property (nonatomic, strong, nullable) JFTAVCustomVideoCompositionTransitionInstruction *transitionInstruction;

@end

NS_ASSUME_NONNULL_END
