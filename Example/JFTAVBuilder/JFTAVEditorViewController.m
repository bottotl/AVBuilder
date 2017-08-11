//
//  JFTAVEditorViewController.m
//  MutableCompotionDemo
//
//  Created by jft0m on 2017/7/7.
//  Copyright © 2017年 jft0m. All rights reserved.
//

#import "JFTAVEditorViewController.h"
#import "R_JFTAVBuilder.h"
#import "JFTAVEditor.h"
#import "APLViewController.h"
#import "JFTVideoPickerController.h"
#import "CIFilter+ColorLUT.h"
#import <Photos/Photos.h>

@interface JFTAVEditorViewController ()
@property (nonatomic, strong) JFTAVTimeLine *timeLine;
@property (nonatomic, strong) AVAsset *selectedAsset;
@end

@implementation JFTAVEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.timeLine = [self createTimeLineWithURLs:[self createVideoURLs]];
}

- (JFTAVTimeLine *)createTimeLineWithURLs:(NSArray <NSURL *> *)urls {
    JFTAVTimeLine *timeLine = [[JFTAVTimeLine alloc] init];
    NSMutableArray *videos = @[].mutableCopy;
    [urls enumerateObjectsUsingBlock:^(NSURL * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
        JFTAVVideoMediaItem *item = [[JFTAVVideoMediaItem alloc] initWithURL:url];
        item.transition.transitionDuration = CMTimeMakeWithSeconds(1, 30);
        item.transition.type = JFTAVVideoMediaItemTransitionTypeFadeInAndFadeOut;
        item.filter = [CIFilter colorCubeWithColrLUTImageNamed:R_defaultLUT dimension:64];
        [videos addObject:item];
    }];
    timeLine.videos = videos;
    timeLine.subtitle = [[JFTAVSubtitlesItem alloc] initWithSubtitles:@"这是一个 Title"];
    timeLine.music = [[JFTAVMusicMediaItem alloc] initWithURL:[self createMusicURL]];
    timeLine.nameOverlay = [[JFTAVOverlayItem alloc] initWithName:@"your name"
                                                  andOverlayImage:[UIImage imageNamed:@"overlay_white"]];
    return timeLine;
}

- (IBAction)exportVideoToAlbum:(id)sender {
    JFTAVBuilder *builder = [JFTAVBuilder builderWithTimeLine:self.timeLine];
    builder.settings.preferredVideoSize = CGSizeMake(1280, 720);
    [builder buildComposition:^(AVComposition *composition) {
        [self exportWithComposition:composition andVideoComposition:builder.videoComposition andAnimationTool:[builder makeAnimationTool]];
    }];
}

- (void)exportWithComposition:(AVComposition *)composition andVideoComposition:(AVMutableVideoComposition *)videoComposition andAnimationTool:(AVVideoCompositionCoreAnimationTool *)animationTool {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"FinalVideo-%d.mp4",arc4random() % 10000000]];
    JFTAVAssetExportSession *exporter = [JFTAVAssetExportSession exportSessionWithAsset:composition];
    videoComposition.animationTool = animationTool;
    exporter.videoComposition = videoComposition;
    exporter.outputURL = [NSURL fileURLWithPath:myPathDocs];
    exporter.videoSettings.dataBitRate = 1600;
    exporter.videoSettings.preferredVideoSize = CGSizeMake(960, 540);
    exporter.timeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(1, 1), CMTimeMakeWithSeconds(2, 1));
    NSLog(@"exportAsynchronouslyWithCompletionHandler");
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        if (!exporter.error) {
            [self saveVideoToAlbum:[NSURL fileURLWithPath:myPathDocs]];
        } else {
            NSLog(@"%@", exporter.error);
        }
    }];
}

- (void)texportWithComposition:(AVComposition *)composition andVideoComposition:(AVMutableVideoComposition *)videoComposition andAnimationTool:(AVVideoCompositionCoreAnimationTool *)animationTool {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"FinalVideo-%d.mp4",arc4random() % 10000000]];
    AVAssetExportSession *session = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPreset960x540];
    session.outputFileType = AVFileTypeMPEG4;
    videoComposition.animationTool = animationTool;
    session.videoComposition = videoComposition;
    session.outputURL = [NSURL fileURLWithPath:myPathDocs];
    NSLog(@"outputURL === :\n%@", session.outputURL);
    [session exportAsynchronouslyWithCompletionHandler:^{
        if (!session.error) {
            [self saveVideoToAlbum:[NSURL fileURLWithPath:myPathDocs]];
        } else {
            NSLog(@"%@", session.error);
        }
    }];
    
}

- (IBAction)pickVideoFormAlbum:(id)sender {
    JFTVideoPickerController *pickerVC = [JFTVideoPickerController new];
    pickerVC.didPickAsset = ^(AVAsset *asset) {
        self.selectedAsset = asset;
        [self addAssetToTimeline:asset];
        [self.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:pickerVC animated:YES];
}

- (void)addAssetToTimeline:(AVAsset *)asset {
    JFTAVVideoMediaItem *video = [[JFTAVVideoMediaItem alloc] initWithAsset:asset];
    video.filter = [CIFilter colorCubeWithColrLUTImageNamed:R_defaultLUT dimension:64];
    self.timeLine.nameOverlay = [[JFTAVOverlayItem alloc] initWithName:@"your name"
                                                  andOverlayImage:[UIImage imageNamed:@"overlay_white"]];
    self.timeLine.videos = @[video].mutableCopy;
}

- (AVVideoCompositionCoreAnimationTool *)makeAnimationTool:(CGRect)renderFrame duration:(CMTime)duration {
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = videoLayer.frame = renderFrame;
    [parentLayer addSublayer:videoLayer];
    
    CALayer *subtitlesLayer = [JFTAVAnimationMaker createTextAnimationLayerWithText:@"this is a title"
                                                                            andType:JFTAVTextAnimationFadeInAndOut
                                                                          withFrame:renderFrame
                                                                        andDuration:duration];
    [parentLayer addSublayer:subtitlesLayer];
    
    return [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer
                                                                                                        inLayer:parentLayer];
}

- (IBAction)showPlayerDebug:(id)sender {
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"CompositionDebug" bundle:nil];
    APLViewController *debugVC = [storyBoard instantiateInitialViewController];
    
    JFTAVBuilder *builder = [JFTAVBuilder builderWithTimeLine:self.timeLine];

    [builder buildComposition:^(AVComposition *composition) {
        if (!composition) {
            NSLog(@"%@", builder.error);
            return;
        }
        NSLog(@"=== build composition success:%@ ===", composition);
        debugVC.composition = composition;
        dispatch_async(dispatch_get_main_queue(), ^{
            debugVC.videoComposition = builder.videoComposition;
            debugVC.audioMix = builder.audioMix;
            debugVC.animationLayer = [builder createAnimationLayer]; 
            [self.navigationController pushViewController:debugVC animated:YES];
        });
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSArray <NSURL *> *)createVideoURLs {
    NSMutableArray *urls = [NSMutableArray array];
    [urls addObjectsFromArray:[[NSBundle mainBundle] URLsForResourcesWithExtension:@"mov" subdirectory:nil]];
    [urls addObjectsFromArray:[[NSBundle mainBundle] URLsForResourcesWithExtension:@"mp4" subdirectory:nil]];
    [urls addObjectsFromArray:[[NSBundle mainBundle] URLsForResourcesWithExtension:@"MP4" subdirectory:nil]];
    return urls;
}

- (NSURL *)createMusicURL {
    return [[NSBundle mainBundle] URLsForResourcesWithExtension:@"mp3" subdirectory:nil].firstObject;
}

- (void)saveVideoToAlbum:(NSURL *)url {
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"save success");
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"success" message:@"Video Save success"
                                                               delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            });
        } else {
            NSLog(@"%@",error);
        }
    }];
}

@end
