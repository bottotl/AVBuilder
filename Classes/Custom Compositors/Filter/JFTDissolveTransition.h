//
//  JFTDissolveTransition.h
//  Pods
//
//  Created by jft0m on 2017/8/10.
//
//

#import <CoreImage/CoreImage.h>

@interface JFTDissolveTransition : NSObject

@property (nonatomic, strong, nonnull) CIImage  *forgroundImage; ///< the forground image from which you want to transition
@property (nonatomic, strong, nonnull) CIImage  *backgroundImage;///< the background image to which you want to transition.

@property (nonatomic, assign, nonnull) NSNumber *inputTime;      ///< min(max(2*(time - 0.25), 0), 1)

@property (nonatomic, readonly, nullable) CIImage *outputImage;
@end
