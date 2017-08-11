//
//  JFTAVMusicMediaItem.m
//  Pods
//
//  Created by jft0m on 2017/7/19.
//
//

#import "JFTAVMusicMediaItem.h"

@implementation JFTAVMusicMediaItem

- (instancetype)initWithURL:(NSURL *)url {
    if (self = [super initWithURL:url]) {
        _mixRate = 0.5;
    }
    return self;
}

@end
