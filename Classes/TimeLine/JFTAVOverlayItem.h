//
//  JFTAVOverlayItem.h
//  Pods
//
//  Created by jft0m on 2017/7/21.
//
//

#import "JFTAVTimeLine.h"

/**
 *  你的名字的水印
 */
@interface JFTAVOverlayItem : JFTAVTimeLine

- (instancetype)initWithName:(NSString *)name
             andOverlayImage:(UIImage *)image;

@property (nonatomic, copy)   NSString *nameText;
@property (nonatomic, strong) UIImage  *overlayImage;
@property (nonatomic, assign) CGPoint   rightBottomPosition;
@property (nonatomic, assign) CGSize    size;

@end
