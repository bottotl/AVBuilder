//
//  JFTAVVideoMediaItem.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/6.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVMediaItem.h"

typedef enum {
    JFTAVVideoMediaItemTransitionTypeNone = 0,
    JFTAVVideoMediaItemTransitionTypeFadeInAndFadeOut ,
    JFTAVVideoMediaItemTransitionTypePush
} JFTAVVideoMediaItemTransitionType;


/**
 *  Transition for media item
 */
@interface JFTAVVideoMediaItemTransition : NSObject
@property (nonatomic, assign) CMTime transitionDuration;
@property (nonatomic, assign) JFTAVVideoMediaItemTransitionType type;
@end

/**
 *  代表了一个可以放到 Time Line 中的视频数据模型
 */
@interface JFTAVVideoMediaItem : JFTAVMediaItem

@property (nonatomic, strong) JFTAVVideoMediaItemTransition *transition;
@property (nonatomic, strong) CIFilter                      *filter;
@property (nonatomic, assign) BOOL                           muted; ///< default is NO

@end
