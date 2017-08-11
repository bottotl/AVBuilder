//
//  JFTAVAnimationMaker.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/11.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVAnimationMaker.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@implementation JFTAVAnimationMaker

+ (CALayer *)createTextAnimationLayerWithText:(NSString *)text
                                      andType:(JFTAVTextAnimationType)type
                                    withFrame:(CGRect)videoFrame
                                  andDuration:(CMTime)duration {
    CATextLayer *textLayer = [[CATextLayer alloc] init];
    [textLayer setFont:@"Helvetica-Bold"];
    [textLayer setFontSize:36];
    [textLayer setFrame:CGRectMake(0,
                                   0,
                                   videoFrame.size.width,
                                   videoFrame.size.height - 100)];
    [textLayer setString:text];
    [textLayer setAlignmentMode:kCAAlignmentCenter];
    textLayer.opacity = 0;
    [textLayer setForegroundColor:[[UIColor whiteColor] CGColor]];
    
    CAKeyframeAnimation *fadeAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    fadeAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
    fadeAnimation.duration  = CMTimeGetSeconds(duration);
    fadeAnimation.values = @[@(0),@(1.0),@(1.0),@(0)];
    fadeAnimation.keyTimes = @[@(0),@(1/8.),@(7/8.),@(1)];
    fadeAnimation.removedOnCompletion = NO;
    [textLayer addAnimation:fadeAnimation forKey:@"fade"];
    
    return textLayer;
}

+ (CALayer *)createNameOverlayLayerWithName:(NSString *)name
                                   andImage:(UIImage *)overlayImage
                                    andType:(JFTAVNameOverlayAnimationType)type
                                  withSize:(CGSize)size
                                andDuration:(CMTime)duration {
    CALayer *overlayLayer = [CALayer layer];
    [overlayLayer setContents:(id)[overlayImage CGImage]];
    overlayLayer.bounds = CGRectMake(0, 0, size.width, size.height);
    [overlayLayer setMasksToBounds:YES];
    return overlayLayer;
}


@end
