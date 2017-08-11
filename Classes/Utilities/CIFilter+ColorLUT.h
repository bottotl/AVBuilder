//
//  CIFilter+ColorLUT.h
//  Pods
//
//  Created by jft0m on 2017/8/11.
//
//

#import <CoreImage/CoreImage.h>

@interface CIFilter (ColorLUT)
+ (CIFilter *)colorCubeWithColrLUTImageNamed:(NSString *)imageName dimension:(NSInteger)n;
@end
