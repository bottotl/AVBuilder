//
//  JFTAVTimelineItem+Private.h
//  Pods
//
//  Created by jft0m on 2017/7/14.
//
//

#import "JFTAVTimelineItem.h"

@interface JFTAVTimelineItem (Private)
@property (nonatomic, assign) CMPersistentTrackID videoTrackID;
@property (nonatomic, assign) CMPersistentTrackID audioTrackID;
@property (nonatomic, assign) CMTimeRange timeRangeInTimeline;// timeRange In time line
@end
