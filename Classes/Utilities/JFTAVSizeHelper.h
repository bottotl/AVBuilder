//
//  JFTAVSizeHelper.h
//  Pods
//
//  Created by jft0m on 2017/8/8.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface JFTAVSizeHelper : NSObject
+ (CGSize)renderSizeWithAssetTrack:(AVAssetTrack *)track andPerferedSize:(CGSize)videoSize;
/// 根据视频的原始尺寸计算缩放到 renderSize 需要缩放多少
+ (CGAffineTransform)scaleTransformWithTrack:(AVAssetTrack *)track andRenderSize:(CGSize)renderSize;

/// There are width requirements for either the iOS encoders or the video format itself. Try making your width even or divisible by 4.
+ (CGSize)fixSize:(CGSize)size;

/// 有时候从视频轨道中读取的 transform 会缺少平移信息，所以需要对偏移信息进行补全
+ (CGAffineTransform)createPreferredTransformWithVideoTrack:(AVAssetTrack *)videoTrack;

@end
