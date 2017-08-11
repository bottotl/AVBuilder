//
//  JFTAVAnimationMaker.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/11.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

typedef NS_ENUM(NSUInteger, JFTAVTextAnimationType) {
    JFTAVTextAnimationFadeInAndOut
};

typedef NS_ENUM(NSUInteger, JFTAVNameOverlayAnimationType) {
    JFTAVNameOverlayAnimationNone
};



@class CALayer;
@interface JFTAVAnimationMaker : NSObject

/**
 创建一个文本的动画 layer
 （但是现在不需要这个功能，所以里面很简陋）

 @param text 需要展示的文本
 @param type 动画类型
 @param frame 视频展示的区域
 @param duration 视频总时长
 @return 可供展示的 layer
 */
+ (CALayer *)createTextAnimationLayerWithText:(NSString *)text
                                      andType:(JFTAVTextAnimationType)type
                                    withFrame:(CGRect)frame
                                  andDuration:(CMTime)duration;
/**
 创建一个图片的水印
 后期可能需要加文字或者动画 我就是方便后期扩展随手创建了剩下的数据结构 （name、type、duration 暂时还没有用）

 @param name 名字（暂时没用）
 @param overlayImage 水印图片
 @param type 动画类型（暂时没用）
 @param size 水印的 size
 @param duration 视频总时长（暂时没用）
 @return 可供展示的 layer
 */
+ (CALayer *)createNameOverlayLayerWithName:(NSString *)name
                                   andImage:(UIImage *)overlayImage
                                    andType:(JFTAVNameOverlayAnimationType)type
                                   withSize:(CGSize)size
                                andDuration:(CMTime)duration;

@end
