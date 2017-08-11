//
//  JFTAVCustomVideoCompositionInstruction.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/10.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVCustomVideoCompositionInstruction.h"

@implementation JFTAVCustomVideoCompositionLayerInstruction

- (instancetype)initWithTrackID:(CMPersistentTrackID)trackID
                      transform:(CGAffineTransform)transform
                      videoItem:(JFTAVVideoMediaItem *)videoItem {
    if (self = [super init]) {
        NSParameterAssert(trackID != kCMPersistentTrackID_Invalid);
        self.trackID = trackID;
        self.transform = transform;
        self.videoItem = videoItem;
    }
    return self;
}

@end

@implementation JFTAVCustomVideoCompositionTransitionInstruction
@end

@interface JFTAVCustomVideoCompositionInstruction ()
@end

@implementation JFTAVCustomVideoCompositionInstruction

+ (instancetype)new {
    JFTAVCustomVideoCompositionInstruction *ins = [[JFTAVCustomVideoCompositionInstruction alloc] init];
    ins.passthroughTrackID = kCMPersistentTrackID_Invalid;
    ins.requiredSourceTrackIDs = nil;
    ins.enablePostProcessing = YES;
    ins.containsTweening = NO;
    ins.timeRange = kCMTimeRangeInvalid;
    return ins;
}

- (void)setTransitionInstruction:(JFTAVCustomVideoCompositionTransitionInstruction *)transitionInstruction {
    _transitionInstruction = transitionInstruction;
    _containsTweening = YES;
}

@end
