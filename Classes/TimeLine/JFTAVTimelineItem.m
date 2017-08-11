//
//  JFTAVTimelineItem.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/6.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVTimelineItem.h"

@interface JFTAVTimelineItem ()

@property (nonatomic, assign) CMPersistentTrackID videoTrackID;
@property (nonatomic, assign) CMPersistentTrackID audioTrackID;
@property (nonatomic, assign) CMTimeRange timeRangeInTimeline;
@end

@implementation JFTAVTimelineItem

- (id)init {
    self = [super init];
    if (self) {
        _timeRange = kCMTimeRangeInvalid;
        _timeRangeInTimeline = kCMTimeRangeInvalid;
        _videoTrackID = kCMPersistentTrackID_Invalid;
        _audioTrackID = kCMPersistentTrackID_Invalid;
    }
    return self;
}

@end
