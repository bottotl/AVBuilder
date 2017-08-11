//
//  JFTAVBuilder+Play.h
//  Pods
//
//  Created by jft0m on 2017/7/21.
//
//

#import "JFTAVBuilder.h"

@interface JFTAVBuilder (Play)

/**
 *  使用 AVPlayer 播放的时候用这个方法去创建一个含有 Core Animaiton 的 layer
 *  根据 self.videoSettings 和 self.timeline 创建所需的含有 Core Animation 的 layer

 @return core animation layer
 */
- (CALayer *)createAnimationLayer;

/**
 *  使用 JFTAVAssetExportSession 导出的时候可以通过这个方法创建一个含有 Core Animation 的 animaiton tool
 *  和 self.videoSettings 和 self.timeline 中的数据相关
 @return animaiton tool
 */
- (AVVideoCompositionCoreAnimationTool *)makeAnimationTool;


/**
 计算缩放比例的工具类
 
 @param videoRect 视频的尺寸
 @param PlayerRect 播放器的尺寸
 @return Core Animation Layer 的 transform 
 */
+ (CGAffineTransform)scaleTransformMaker:(CGRect)videoRect andPlayerRect:(CGRect)PlayerRect;

@end
