//
//  JFTAVBuilderSettings.h
//  Pods
//
//  Created by jft0m on 2017/8/7.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface JFTAVBuilderSettings : NSObject
@property (nonatomic, assign) CMTime frameDuration;
@property (nonatomic, assign) CGSize preferredVideoSize;
@property (nonatomic, assign, readonly) CGSize videoSize;
@end
