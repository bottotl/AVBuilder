//
//  JFTAVMusicMediaItem.h
//  Pods
//
//  Created by jft0m on 2017/7/19.
//
//

#import "JFTAVMediaItem.h"

@interface JFTAVMusicMediaItem : JFTAVMediaItem


/**
 *  和视频声音的的混合比例 default is 0.5
 *  从 0 ... 1
 *  0 表示 完全没有音乐
 *  1 表示 完全都是音乐
 */
@property (nonatomic, assign) CGFloat mixRate;

@end
