//
//  JFTAVSubtitlesItem.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/11.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVSubtitlesItem.h"

@interface JFTAVSubtitlesItem ()

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) JFTAVSubtitlesStyle style;
@property (nonatomic, assign) JFTAVSubtitlesPosition position;

@end

@implementation JFTAVSubtitlesItem

- (instancetype)initWithSubtitles:(NSString *)title andPosition:(JFTAVSubtitlesPosition)position andStyle:(JFTAVSubtitlesStyle)style {
    if (self = [super init]) {
        _position = position;
        _title = title;
        _style = style;
    }
    return self;
}

- (instancetype)initWithSubtitles:(NSString *)title {
    return [self initWithSubtitles:title andPosition:JFTAVSubtitlesPositionBottomCenter andStyle:JFTAVSubtitlesStyleAll];
}

@end
