//
//  JFTDissolveTransition.m
//  Pods
//
//  Created by jft0m on 2017/8/10.
//
//

#import "JFTDissolveTransition.h"

@interface JFTDissolveTransition ()
@property (nonatomic, strong) CIFilter *filter;
@end

@implementation JFTDissolveTransition

+ (instancetype)new {
    JFTDissolveTransition *transition = [[JFTDissolveTransition alloc] init];
    transition.filter = [CIFilter filterWithName:@"CIDissolveTransition"];
    return transition;
}

- (void)setForgroundImage:(CIImage *)forgroundImage {
    _forgroundImage = forgroundImage;
    [self.filter setValue:forgroundImage forKey:@"inputImage"];
}

- (void)setBackgroundImage:(CIImage *)backgroundImage {
    _backgroundImage = backgroundImage;
    [self.filter setValue:backgroundImage forKey:@"inputTargetImage"];
}

- (void)setInputTime:(NSNumber *)inputTime {
    _inputTime = inputTime;
    [self.filter setValue:self.inputTime forKey:@"inputTime"];
}

- (CIImage *)outputImage {
    return self.filter.outputImage;
}

@end
