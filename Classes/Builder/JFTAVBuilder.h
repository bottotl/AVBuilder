//
//  JFTAVBuilder.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/7.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "JFTAVTimeLine.h"
#import "JFTAVBuilderSettings.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, JFTAVBuildStatus) {
    JFTAVBuildStatusInit     ,
    JFTAVBuildStatusBuilding ,
    JFTAVBuildStatusComplete ,
    JFTAVBuildStatusFail
};

@interface JFTAVBuilder : NSObject

@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly) JFTAVBuildStatus status;
@property (nonatomic, strong, nullable) JFTAVTimeLine *timeLine;

@property (nonatomic, strong, nullable) JFTAVBuilderSettings *settings;

@property (nonatomic, readonly, nullable) AVMutableComposition      *composition;
@property (nonatomic, readonly, nullable) AVMutableAudioMix         *audioMix;
@property (nonatomic, readonly, nullable) AVMutableVideoComposition *videoComposition;

+ (instancetype)builderWithTimeLine:(JFTAVTimeLine *)timeLine;

/**
 *  分析 time line 重新生成 composition。

 @param completionBlock composition 可能为空。可以通过 status 和 error 获取当前 builder 的状态和可能出现的错误
 */
- (void)buildComposition:(void(^ __nullable)(AVMutableComposition * __nullable composition))completionBlock;

#pragma mark - Export
/// create video composition for export

//- (AVVideoComposition *)makeVideoCompositonForExport;

//- (AVVideoCompositionCoreAnimationTool *)makeAnimationTool:(CGRect)renderFrame;

- (void)buildTimeline;
- (void)reset;

@end
NS_ASSUME_NONNULL_END
