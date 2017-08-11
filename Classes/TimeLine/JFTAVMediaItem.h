//
//  JFTAVMediaItem.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/6.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "JFTAVTimelineItem.h"

typedef NS_ENUM(NSUInteger, JFTAVMediaItemStatus) {
    JFTAVMediaItemStatusUnknown ,
    JFTAVMediaItemStatusLoading ,
    JFTAVMediaItemStatusLoaded  ,
    JFTAVMediaItemStatusFailed
};

/// 只是给继承用。请不要直接使用这个 Class
@interface JFTAVMediaItem : JFTAVTimelineItem

@property (nonatomic, readonly) NSString *mediaType;

@property (nonatomic, readonly) AVAsset *asset;

@property (nonatomic, strong, readonly) NSError *error;
@property (nonatomic, assign, readonly) JFTAVMediaItemStatus status;

- (instancetype)initWithURL:(NSURL *)url;
- (instancetype)initWithAsset:(AVAsset *)asset;

@end
