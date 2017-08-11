//
//  JFTAVMediaItem+Private.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/8.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVMediaItem.h"

@interface JFTAVMediaItem (Private)

- (void)prepareWithCompletionBlock:(void(^)(JFTAVMediaItemStatus status))block;

@end
