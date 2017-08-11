//
//  JFTVideoPickerCollectionViewCell.m
//  JFTAVEditor
//
//  Created by jft0m on 2017/8/2.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTVideoPickerCollectionViewCell.h"

@interface JFTVideoPickerCollectionViewCell ()
@property (nonatomic, strong) CAGradientLayer *maskLayer;
@property (nonatomic, strong) UILabel *durationLabel;
@end

@implementation JFTVideoPickerCollectionViewCell
- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        
        _imageView = [UIImageView new];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self.contentView addSubview:_imageView];
        
        [_imageView.layer addSublayer:self.maskLayer];
        
        _durationLabel = [UILabel new];
        _durationLabel.numberOfLines = 1;
        _durationLabel.font = [UIFont systemFontOfSize:14.f];
        [_durationLabel setTextColor:[UIColor whiteColor]];
        [self.contentView addSubview:_durationLabel];
        
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    self.imageView.frame = self.contentView.bounds;
    self.maskLayer.frame = self.contentView.bounds;
    
    self.durationLabel.frame = self.contentView.bounds;
    
}

- (void)setDurationText:(NSString *)durationText {
    _durationText = durationText;
    self.durationLabel.text = _durationText;
}

- (CAGradientLayer *)maskLayer {
    if (!_maskLayer) {
        _maskLayer = [CAGradientLayer layer];
        _maskLayer.colors = @[(__bridge id)[UIColor colorWithWhite:0 alpha:0.5].CGColor, (__bridge id)[UIColor colorWithWhite:0 alpha:0].CGColor];
        _maskLayer.startPoint = CGPointMake(0.5, 1);
        _maskLayer.endPoint = CGPointMake(0.5, 0);
    }
    return _maskLayer;
}


@end
