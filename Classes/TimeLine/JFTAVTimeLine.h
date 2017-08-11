//
//  JFTAVTimeLine.h
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/6.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JFTAVVideoMediaItem.h"

@class JFTAVVideoMediaItem, JFTAVSubtitlesItem, JFTAVMusicMediaItem, JFTAVOverlayItem;
/// 只是用来持有 Media items ,需要结合 JFTAVBuilder 来使用
@interface JFTAVTimeLine : NSObject

@property (nonatomic, strong) NSMutableArray <JFTAVVideoMediaItem *> *videos;
@property (nonatomic, strong) JFTAVSubtitlesItem  *subtitle;
@property (nonatomic, strong) JFTAVMusicMediaItem *music;
@property (nonatomic, strong) JFTAVOverlayItem    *nameOverlay;

@end
