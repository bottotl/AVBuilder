//
//  JFTAVVideoMediaItem.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/6.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVVideoMediaItem.h"

@implementation JFTAVVideoMediaItem

- (instancetype)initWithURL:(NSURL *)url {
    if (self = [super initWithURL:url]) {
        _transition = [[JFTAVVideoMediaItemTransition alloc] init];
        _muted = NO;
    }
    return self;
}

- (NSString *)mediaType {
    return AVMediaTypeVideo;
}

@end

@implementation JFTAVVideoMediaItemTransition

- (instancetype)init {
    if (self = [super init]) {
        _transitionDuration = kCMTimeZero;
        _type = JFTAVVideoMediaItemTransitionTypeNone;
    }
    return self;
}

@end
