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
#import "CIFilter+ColorLUT.h"
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

@interface JFTAVEditorViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) JFTAVTimeLine *timeLine;
@property (nonatomic, strong) AVAsset *selectedAsset;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

// 新增UI组件
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *playerContainerView;
@property (nonatomic, strong) UITableView *videoListTableView;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *addVideoButton;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) id timeObserver;
@end

@implementation JFTAVEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.timeLine = [self createTimeLineWithURLs:[self createVideoURLs]];
    [self setupUI];
    [self setupPlayer];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"视频编辑器";

    // 1. 视频预览容器
    self.playerContainerView = [[UIView alloc] init];
    self.playerContainerView.backgroundColor = [UIColor blackColor];
    self.playerContainerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.playerContainerView];

    // 2. 播放控制区域
    UIView *controlsView = [[UIView alloc] init];
    controlsView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    controlsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:controlsView];

    // 播放按钮
    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.playButton setTitle:@"▶️ 播放" forState:UIControlStateNormal];
    [self.playButton setTitle:@"⏸ 暂停" forState:UIControlStateSelected];
    self.playButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playButton addTarget:self action:@selector(playButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [controlsView addSubview:self.playButton];

    // 进度条
    self.progressSlider = [[UISlider alloc] init];
    self.progressSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressSlider.minimumValue = 0;
    self.progressSlider.maximumValue = 1;
    [self.progressSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [controlsView addSubview:self.progressSlider];

    // 时间标签
    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.text = @"00:00 / 00:00";
    self.timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.timeLabel.textColor = [UIColor darkGrayColor];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [controlsView addSubview:self.timeLabel];

    // 3. 视频列表
    self.videoListTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.videoListTableView.delegate = self;
    self.videoListTableView.dataSource = self;
    self.videoListTableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.videoListTableView.rowHeight = 60;
    self.videoListTableView.allowsSelection = YES;
    [self.videoListTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"VideoCell"];
    [self.view addSubview:self.videoListTableView];

    // 4. 底部按钮区域
    UIView *bottomButtonsView = [[UIView alloc] init];
    bottomButtonsView.backgroundColor = [UIColor whiteColor];
    bottomButtonsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bottomButtonsView];

    self.addVideoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.addVideoButton setTitle:@"➕ 添加视频" forState:UIControlStateNormal];
    self.addVideoButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.addVideoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.addVideoButton addTarget:self action:@selector(pickVideoFormAlbum:) forControlEvents:UIControlEventTouchUpInside];
    [bottomButtonsView addSubview:self.addVideoButton];

    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.exportButton setTitle:@"💾 导出视频" forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.exportButton addTarget:self action:@selector(exportVideoToAlbum:) forControlEvents:UIControlEventTouchUpInside];
    [bottomButtonsView addSubview:self.exportButton];

    UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [debugButton setTitle:@"🔍 调试" forState:UIControlStateNormal];
    debugButton.titleLabel.font = [UIFont systemFontOfSize:14];
    debugButton.translatesAutoresizingMaskIntoConstraints = NO;
    [debugButton addTarget:self action:@selector(showPlayerDebug:) forControlEvents:UIControlEventTouchUpInside];
    [bottomButtonsView addSubview:debugButton];

    // 设置进度视图（导出时使用）
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.progress = 0.0;
    self.progressView.hidden = YES;
    [self.view addSubview:self.progressView];

    // 状态标签
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.hidden = YES;
    [self.view addSubview:self.statusLabel];

    // 活动指示器

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];

    // 布局约束
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // 播放器容器
        [self.playerContainerView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.playerContainerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.playerContainerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.playerContainerView.heightAnchor constraintEqualToConstant:250],

        // 控制区域
        [controlsView.topAnchor constraintEqualToAnchor:self.playerContainerView.bottomAnchor],
        [controlsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [controlsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [controlsView.heightAnchor constraintEqualToConstant:80],

        // 播放按钮
        [self.playButton.leadingAnchor constraintEqualToAnchor:controlsView.leadingAnchor constant:16],
        [self.playButton.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor],
        [self.playButton.widthAnchor constraintEqualToConstant:80],

        // 进度条
        [self.progressSlider.leadingAnchor constraintEqualToAnchor:self.playButton.trailingAnchor constant:12],
        [self.progressSlider.trailingAnchor constraintEqualToAnchor:controlsView.trailingAnchor constant:-16],
        [self.progressSlider.centerYAnchor constraintEqualToAnchor:controlsView.centerYAnchor constant:-10],

        // 时间标签
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:controlsView.trailingAnchor constant:-16],
        [self.timeLabel.topAnchor constraintEqualToAnchor:self.progressSlider.bottomAnchor constant:4],

        // 视频列表
        [self.videoListTableView.topAnchor constraintEqualToAnchor:controlsView.bottomAnchor],
        [self.videoListTableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.videoListTableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.videoListTableView.bottomAnchor constraintEqualToAnchor:bottomButtonsView.topAnchor],

        // 底部按钮区域
        [bottomButtonsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bottomButtonsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bottomButtonsView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [bottomButtonsView.heightAnchor constraintEqualToConstant:60],

        // 按钮布局
        [self.addVideoButton.leadingAnchor constraintEqualToAnchor:bottomButtonsView.leadingAnchor constant:16],
        [self.addVideoButton.centerYAnchor constraintEqualToAnchor:bottomButtonsView.centerYAnchor],

        [self.exportButton.trailingAnchor constraintEqualToAnchor:bottomButtonsView.trailingAnchor constant:-16],
        [self.exportButton.centerYAnchor constraintEqualToAnchor:bottomButtonsView.centerYAnchor],

        [debugButton.centerXAnchor constraintEqualToAnchor:bottomButtonsView.centerXAnchor],
        [debugButton.centerYAnchor constraintEqualToAnchor:bottomButtonsView.centerYAnchor],

        // 导出进度视图
        [self.progressView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.progressView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.progressView.widthAnchor constraintEqualToConstant:250],

        [self.statusLabel.topAnchor constraintEqualToAnchor:self.progressView.bottomAnchor constant:10],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.widthAnchor constraintEqualToConstant:300],

        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.bottomAnchor constraintEqualToAnchor:self.progressView.topAnchor constant:-10]
    ]];
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
    [self showLoadingWithMessage:@"正在准备导出..."];

    JFTAVBuilder *builder = [JFTAVBuilder builderWithTimeLine:self.timeLine];
    builder.settings.preferredVideoSize = CGSizeMake(1280, 720);
    [builder buildComposition:^(AVComposition *composition) {
        if (!composition) {
            [self hideLoading];
            [self showAlertWithTitle:@"错误" message:@"无法创建视频合成" completion:nil];
            return;
        }
        [self exportWithComposition:composition andVideoComposition:builder.videoComposition andAnimationTool:[builder makeAnimationTool]];
    }];
}

- (void)showLoadingWithMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.hidden = NO;
        self.progressView.progress = 0.0;
        self.statusLabel.hidden = NO;
        self.statusLabel.text = message;
        [self.activityIndicator startAnimating];
        self.view.userInteractionEnabled = NO;
    });
}

- (void)hideLoading {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.hidden = YES;
        self.statusLabel.hidden = YES;
        [self.activityIndicator stopAnimating];
        self.view.userInteractionEnabled = YES;
    });
}

- (void)updateProgress:(float)progress withMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.progress = progress;
        if (message) {
            self.statusLabel.text = message;
        }
    });
}

- (void)exportWithComposition:(AVComposition *)composition andVideoComposition:(AVMutableVideoComposition *)videoComposition andAnimationTool:(AVVideoCompositionCoreAnimationTool *)animationTool {
    [self updateProgress:0.1 withMessage:@"正在导出视频..."];

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

    // 创建一个定时器来更新进度
    NSTimer *progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
        float progress = exporter.progress;
        [self updateProgress:0.1 + progress * 0.8 withMessage:[NSString stringWithFormat:@"正在导出视频... %.0f%%", progress * 100]];
    }];

    NSLog(@"exportAsynchronouslyWithCompletionHandler");
    __weak typeof(self) weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        [progressTimer invalidate];
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!exporter.error) {
            [strongSelf updateProgress:0.9 withMessage:@"正在保存到相册..."];
            [strongSelf saveVideoToAlbum:[NSURL fileURLWithPath:myPathDocs]];
        } else {
            [strongSelf hideLoading];
            [strongSelf showAlertWithTitle:@"导出失败" message:[NSString stringWithFormat:@"错误: %@", exporter.error.localizedDescription] completion:nil];
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
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];

    // 只选择视频
    PHPickerFilter *videoFilter = [PHPickerFilter videosFilter];
    config.filter = videoFilter;

    // 选择数量限制
    config.selectionLimit = 5; // 可以选择多个视频

    // 设置选择模式
    config.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCurrent;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;

    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (results.count == 0) {
        return; // 用户取消选择
    }

    [self showLoadingWithMessage:@"正在加载视频..."];

    NSMutableArray *videoAssets = [NSMutableArray array];
    __block NSInteger loadedCount = 0;
    NSInteger totalCount = results.count;

    for (PHPickerResult *result in results) {
        NSItemProvider *provider = result.itemProvider;

        if ([provider hasItemConformingToTypeIdentifier:@"public.movie"]) {
            [provider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (url) {
                    // 复制文件到临时目录，因为原始文件可能会被删除
                    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"video_%ld.mp4", (long)[[NSDate date] timeIntervalSince1970]]];
                    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];

                    NSError *copyError;
                    [[NSFileManager defaultManager] copyItemAtURL:url toURL:tempURL error:&copyError];

                    if (!copyError) {
                        AVAsset *asset = [AVAsset assetWithURL:tempURL];
                        [videoAssets addObject:asset];
                    }
                }

                loadedCount++;

                // 所有视频加载完成
                if (loadedCount == totalCount) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideLoading];
                        if (videoAssets.count > 0) {
                            [self addMultipleAssetsToTimeline:videoAssets];
                            [self.videoListTableView reloadData];
                            [self setupPlayer];
                            [self showAlertWithTitle:@"成功" message:[NSString stringWithFormat:@"已添加 %ld 个视频", (long)videoAssets.count] completion:nil];
                        } else {
                            [self showAlertWithTitle:@"错误" message:@"无法加载选中的视频" completion:nil];
                        }
                    });
                }
            }];
        } else {
            loadedCount++;
        }
    }
}

- (void)addAssetToTimeline:(AVAsset *)asset {
    JFTAVVideoMediaItem *video = [[JFTAVVideoMediaItem alloc] initWithAsset:asset];
    video.filter = [CIFilter colorCubeWithColrLUTImageNamed:R_defaultLUT dimension:64];
    video.transition.transitionDuration = CMTimeMakeWithSeconds(1, 30);
    video.transition.type = JFTAVVideoMediaItemTransitionTypeFadeInAndFadeOut;
    self.timeLine.nameOverlay = [[JFTAVOverlayItem alloc] initWithName:@"your name"
                                                  andOverlayImage:[UIImage imageNamed:@"overlay_white"]];

    // 追加到现有视频数组，而不是替换
    NSMutableArray *videos = [self.timeLine.videos mutableCopy];
    if (!videos) {
        videos = [NSMutableArray array];
    }
    [videos addObject:video];
    self.timeLine.videos = videos;
}

- (void)addMultipleAssetsToTimeline:(NSArray<AVAsset *> *)assets {
    // 从现有视频数组开始，而不是创建新数组
    NSMutableArray *videos = [self.timeLine.videos mutableCopy];
    if (!videos) {
        videos = [NSMutableArray array];
    }

    for (AVAsset *asset in assets) {
        JFTAVVideoMediaItem *video = [[JFTAVVideoMediaItem alloc] initWithAsset:asset];
        video.filter = [CIFilter colorCubeWithColrLUTImageNamed:R_defaultLUT dimension:64];
        video.transition.transitionDuration = CMTimeMakeWithSeconds(1, 30);
        video.transition.type = JFTAVVideoMediaItemTransitionTypeFadeInAndFadeOut;
        [videos addObject:video];
    }

    self.timeLine.videos = videos;
    self.timeLine.nameOverlay = [[JFTAVOverlayItem alloc] initWithName:@"your name"
                                                  andOverlayImage:[UIImage imageNamed:@"overlay_white"]];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideLoading];
            if (success) {
                NSLog(@"save success");
                [self showAlertWithTitle:@"成功" message:@"视频已成功保存到相册" completion:^{
                    // 可以在这里添加额外的操作，比如分享或预览
                }];
            } else {
                NSLog(@"%@", error);
                NSString *errorMessage = error ? error.localizedDescription : @"未知错误";
                [self showAlertWithTitle:@"保存失败" message:[NSString stringWithFormat:@"无法保存到相册: %@", errorMessage] completion:nil];
            }
        });
    }];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message completion:(void(^)(void))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
        if (completion) {
            completion();
        }
    }];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Player Methods

- (void)setupPlayer {
    // 清理旧播放器
    if (self.player) {
        [self.player pause];
        if (self.timeObserver) {
            [self.player removeTimeObserver:self.timeObserver];
            self.timeObserver = nil;
        }
        [self.playerLayer removeFromSuperlayer];
    }

    // 创建合成
    JFTAVBuilder *builder = [JFTAVBuilder builderWithTimeLine:self.timeLine];
    [builder buildComposition:^(AVComposition *composition) {
        if (!composition) {
            NSLog(@"Failed to create composition");
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            // 创建播放器项
            AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:composition];
            playerItem.videoComposition = builder.videoComposition;
            playerItem.audioMix = builder.audioMix;

            // 创建播放器
            self.player = [AVPlayer playerWithPlayerItem:playerItem];

            // 设置播放器图层
            self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
            self.playerLayer.frame = self.playerContainerView.bounds;
            self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
            [self.playerContainerView.layer addSublayer:self.playerLayer];

            // 添加时间观察者
            __weak typeof(self) weakSelf = self;
            self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10)
                                                                           queue:dispatch_get_main_queue()
                                                                      usingBlock:^(CMTime time) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf updatePlayerProgress];
            }];

            // 监听播放结束
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(playerDidFinishPlaying:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:playerItem];
        });
    }];
}

- (void)updatePlayerProgress {
    if (!self.player || !self.player.currentItem) return;

    CMTime current = self.player.currentTime;
    CMTime duration = self.player.currentItem.duration;

    if (CMTIME_IS_VALID(duration) && duration.value > 0) {
        float progress = CMTimeGetSeconds(current) / CMTimeGetSeconds(duration);
        self.progressSlider.value = progress;

        NSString *currentTime = [self formatTime:CMTimeGetSeconds(current)];
        NSString *totalTime = [self formatTime:CMTimeGetSeconds(duration)];
        self.timeLabel.text = [NSString stringWithFormat:@"%@ / %@", currentTime, totalTime];
    }
}

- (NSString *)formatTime:(Float64)seconds {
    int mins = (int)seconds / 60;
    int secs = (int)seconds % 60;
    return [NSString stringWithFormat:@"%02d:%02d", mins, secs];
}

- (void)playButtonTapped:(UIButton *)sender {
    if (self.player.rate == 0) {
        [self.player play];
        sender.selected = YES;
    } else {
        [self.player pause];
        sender.selected = NO;
    }
}

- (void)sliderValueChanged:(UISlider *)slider {
    if (!self.player || !self.player.currentItem) return;

    CMTime duration = self.player.currentItem.duration;
    if (CMTIME_IS_VALID(duration)) {
        Float64 newTime = CMTimeGetSeconds(duration) * slider.value;
        [self.player seekToTime:CMTimeMakeWithSeconds(newTime, 600)];
    }
}

- (void)playerDidFinishPlaying:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.playButton.selected = NO;
        [self.player seekToTime:kCMTimeZero];
    });
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.playerLayer) {
        self.playerLayer.frame = self.playerContainerView.bounds;
    }
}

- (void)dealloc {
    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.timeLine.videos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VideoCell" forIndexPath:indexPath];

    // 设置 cell 样式
    if (!cell.detailTextLabel) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"VideoCell"];
    }

    JFTAVVideoMediaItem *video = self.timeLine.videos[indexPath.row];
    AVAsset *asset = video.asset;

    // 获取视频时长
    CMTime duration = asset.duration;
    Float64 seconds = CMTimeGetSeconds(duration);
    NSString *durationString = [self formatTime:seconds];

    // 设置cell内容
    cell.textLabel.text = [NSString stringWithFormat:@"🎬 视频片段 %ld", (long)(indexPath.row + 1)];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"时长: %@  |  转场: %@",
                                 durationString,
                                 video.transition.type == JFTAVVideoMediaItemTransitionTypeFadeInAndFadeOut ? @"淡入淡出" : @"无"];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSMutableArray *videos = [self.timeLine.videos mutableCopy];
        [videos removeObjectAtIndex:indexPath.row];
        self.timeLine.videos = videos;

        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        // 重新设置播放器
        if (videos.count > 0) {
            [self setupPlayer];
        } else {
            [self.player pause];
            self.playButton.selected = NO;
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSMutableArray *videos = [self.timeLine.videos mutableCopy];
    JFTAVVideoMediaItem *movedVideo = videos[sourceIndexPath.row];
    [videos removeObjectAtIndex:sourceIndexPath.row];
    [videos insertObject:movedVideo atIndex:destinationIndexPath.row];
    self.timeLine.videos = videos;

    // 重新设置播放器以反映新的顺序
    [self setupPlayer];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 删除操作
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                               title:@"删除"
                                                                             handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        NSMutableArray *videos = [self.timeLine.videos mutableCopy];
        [videos removeObjectAtIndex:indexPath.row];
        self.timeLine.videos = videos;

        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        if (videos.count > 0) {
            [self setupPlayer];
        } else {
            [self.player pause];
            self.playButton.selected = NO;
        }
        completionHandler(YES);
    }];
    deleteAction.backgroundColor = [UIColor systemRedColor];

    return [UISwipeActionsConfiguration configurationWithActions:@[deleteAction]];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    // 显示操作菜单
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"视频片段操作"
                                                                  message:[NSString stringWithFormat:@"对视频片段 %ld 进行操作", (long)(indexPath.row + 1)]
                                                           preferredStyle:UIAlertControllerStyleActionSheet];

    // 编辑模式切换
    UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"重新排序"
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction * _Nonnull action) {
        [tableView setEditing:!tableView.isEditing animated:YES];
    }];

    // 删除操作
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"删除"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSMutableArray *videos = [self.timeLine.videos mutableCopy];
        [videos removeObjectAtIndex:indexPath.row];
        self.timeLine.videos = videos;

        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];

        if (videos.count > 0) {
            [self setupPlayer];
        } else {
            [self.player pause];
            self.playButton.selected = NO;
        }
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [menu addAction:editAction];
    [menu addAction:deleteAction];
    [menu addAction:cancelAction];

    // iPad 支持
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        menu.popoverPresentationController.sourceView = cell;
        menu.popoverPresentationController.sourceRect = cell.bounds;
    }

    [self presentViewController:menu animated:YES completion:nil];
}

@end
