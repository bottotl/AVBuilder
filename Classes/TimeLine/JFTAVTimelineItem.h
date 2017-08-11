//
//  JFTAVTimelineItem.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/6.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>

@interface JFTAVTimelineItem : NSObject

@property (nonatomic, assign) CMTimeRange timeRange;// timeRange in the origin resource
@property (nonatomic, assign, readonly) CMTimeRange timeRangeInTimeline;// timeRange In time line

@end
