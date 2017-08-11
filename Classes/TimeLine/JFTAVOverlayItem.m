//
//  JFTAVOverlayItem.m
//  Pods
//
//  Created by jft0m on 2017/7/21.
//
//

#import "JFTAVOverlayItem.h"

@implementation JFTAVOverlayItem

- (instancetype)initWithName:(NSString *)name
             andOverlayImage:(UIImage *)image {
    if (self = [super init]) {
        _nameText = name;
        _overlayImage = image;
        _rightBottomPosition = CGPointMake(1, 1);
        _size = CGSizeMake(60, 60);
    }
    return self;
}

@end
