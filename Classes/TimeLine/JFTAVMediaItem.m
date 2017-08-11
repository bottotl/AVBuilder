//
//  JFTAVMediaItem.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/6.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVMediaItem.h"

static NSString *const AVAssetTracksKey = @"tracks";
static NSString *const AVAssetDurationKey = @"duration";
static NSString *const AVAssetCommonMetadataKey = @"commonMetadata";

@interface JFTAVMediaItem ()

@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) JFTAVMediaItemStatus status;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, strong) NSURL  *url;

@end

@implementation JFTAVMediaItem

- (id)initWithURL:(NSURL *)url {
    if (!url || ![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        return nil;
    }
    
    self = [super init];
    if (self) {
        _url = url;
        _filename = [[url lastPathComponent] copy];
        _asset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
        _status = JFTAVMediaItemStatusUnknown;
    }
    return self;
}

- (instancetype)initWithAsset:(AVAsset *)asset {
    if (!asset) return nil;
    if (self = [super init]) {
        _asset = asset;
        _status = JFTAVMediaItemStatusUnknown;
    }
    return self;
}

- (NSString *)mediaType {
    NSAssert(NO, @"Must be overridden in subclass.");
    return nil;
}

- (NSString *)title {
    if (!_title) {
        for (AVMetadataItem *metaItem in [self.asset commonMetadata]) {
            if ([metaItem.commonKey isEqualToString:AVMetadataCommonKeyTitle]) {
                _title = [metaItem stringValue];
                break;
            }
        }
    }
    if (!_title) {
        _title = self.filename;
    }
    return _title;
}

- (void)prepareWithCompletionBlock:(void(^)(JFTAVMediaItemStatus status))completionBlock {
    if (!self.asset) {
        self.status = JFTAVMediaItemStatusFailed;
        if (completionBlock) {
            completionBlock(JFTAVMediaItemStatusFailed);
        }
        return;
    }
    
    [self.asset loadValuesAsynchronouslyForKeys:@[AVAssetTracksKey, AVAssetDurationKey, AVAssetCommonMetadataKey]
                              completionHandler:^{
        AVKeyValueStatus tracksStatus = [self loadAssetValueForKey:AVAssetTracksKey];
        AVKeyValueStatus durationStatus = [self loadAssetValueForKey:AVAssetDurationKey];
        
        /// 当且仅当 tracksStatus 和 durationStatus 都完成加载（AVKeyValueStatusLoaded）的时候才能被 Time Line 中使用
        /// commonMetadata 暂时没有用到，后期如果需要用了再纳入这个状态监测的范围
        BOOL prepared = (tracksStatus == AVKeyValueStatusLoaded) && (durationStatus == AVKeyValueStatusLoaded);
        if (prepared) {
            self.timeRange = CMTimeRangeMake(kCMTimeZero, self.asset.duration);
            self.status = JFTAVMediaItemStatusLoaded;
        } else {
            if (tracksStatus == AVKeyValueStatusLoading || durationStatus == AVKeyValueStatusLoading) {
                self.status = JFTAVMediaItemStatusLoading;
            }
            if (tracksStatus == AVKeyValueStatusFailed || durationStatus == AVKeyValueStatusFailed) {
                self.status = JFTAVMediaItemStatusFailed;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(self.status);
            }
        });
    }];
}

- (AVKeyValueStatus)loadAssetValueForKey:(NSString *const)key {
    NSAssert(self.asset, @"asset can't be nil");
    NSError *error;
    AVKeyValueStatus status = [self.asset statusOfValueForKey:key error:&error];
    if (error && !self.error) {// 如果获取属性失败
        self.error = error;
        NSLog(@"=== JFT Media item load asset value error :%@", error);
    }
    return status;
}

@end
