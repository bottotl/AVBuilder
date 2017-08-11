//
//  JFTAVSubtitlesItem.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/11.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVTimelineItem.h"

typedef enum : NSUInteger {
    JFTAVSubtitlesPositionBottomLeft,
    JFTAVSubtitlesPositionBottomCenter,
    JFTAVSubtitlesPositionBottomRight
} JFTAVSubtitlesPosition;

typedef enum : NSUInteger {
    JFTAVSubtitlesStyleAll    ,
    JFTAVSubtitlesStyleMiddle ,
    JFTAVSubtitlesStyleEnd
} JFTAVSubtitlesStyle;

@interface JFTAVSubtitlesItem : JFTAVTimelineItem

@property (readonly) NSString *title;
@property (readonly) JFTAVSubtitlesStyle style;
@property (readonly) JFTAVSubtitlesPosition position;

- (instancetype)initWithSubtitles:(NSString *)title andPosition:(JFTAVSubtitlesPosition)position andStyle:(JFTAVSubtitlesStyle)style ;
- (instancetype)initWithSubtitles:(NSString *)title;

@end
