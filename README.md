# AVBuilder

![示意图](http://wx3.sinaimg.cn/large/6b5f103fgy1fij4k3d1j8j20o00fnq5n.jpg)

## How to use

### 创建 Time Line

#### Create video

    UGCAVVideoMediaItem *item = [[UGCAVVideoMediaItem alloc] initWithURL:url];
    item.filterComplex = [UGCFilterComplex filterFromType:UGCFilterTypeDessert];
    item.filterComplex.needsSharpenAtFilterChainEnd = YES;     
    item.transition.transitionDuration = CMTimeMakeWithSeconds(1, 30);
    item.transition.type = UGCAVVideoMediaItemTransitionTypeFadeInAndFadeOut;

#### Create music

    timeLine.music = [[UGCAVMusicMediaItem alloc] initWithURL:musicUrl]; 
    
#### Create Overlay

    timeLine.nameOverlay = [[UGCAVOverlayItem alloc] initWithName:@"your  andOverlayImage:[UIImage imageNamed:@“overlay_white"]];
    
### Use Builder

++**Example:**++

    UGCAVBuilder *builder = [UGCAVBuilder builderWithTimeLine:self.timeLine];
    builder.settings.preferredVideoSize = CGSizeMake(1280, 720);
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
----    
#### For Playback

##### 1.设置视频尺寸（默认540*960）
    builder.settings.preferredVideoSize = CGSizeMake(1280, 720);
    
##### 2.生成 composition 

    [UGCAVBuilder:buildComposition:(void(^)(AVMutableComposition * _Nullable composition ))completionBlock]
##### 3.从 Builder 中获取数据

    builder.videoComposition
    builder.audioMix
    [builder createAnimationLayer]
ps:创建 animation layer 的方法在 UGCAVBuilder+Play 中

##### 4.创建 PlayerItem

    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:self.composition];
    playerItem.videoComposition = self.videoComposition;
    playerItem.audioMix = self.audioMix;
    
##### 5.创建 AVSynchronizedLayer （如果需要展示水印、字幕才需要使用这个）

     self.synLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:playerItem];
    [self.synLayer addSublayer:self.animationLayer];
    
    [self.playerView.layer addSublayer:self.synLayer];
    [self.animationLayer setAffineTransform:[UGCAVBuilder scaleTransformMaker:CGRectMake(0, 0, self.videoComposition.renderSize.width, self.videoComposition.renderSize.height) andPlayerRect:self.playerView.frame]];

++为什么要对 animation layer 进行缩放？++

1. 水印的大小应该是相对于视频的尺寸而言的。使用方在最开始调用的时候只知道“期望得到多大的视频”、“水印相对于视频的大小”
2. 视频在播放的时候大小随时可能会改变

**注意！加了 transform 以后不可以修改 frame
你应该修改 position 和 bounds**

    self.animationLayer.position = CGPointMake(self.playerView.bounds.size.width / 2, self.playerView.bounds.size.height / 2);

> The layer’s frame rectangle.
> The frame rectangle is position and size of the layer specified in the superlayer’s coordinate space. For layers, the frame rectangle is a computed property that is derived from the values in thebounds, anchorPoint and position properties. When you assign a new value to this property, the layer changes its position and bounds properties to match the rectangle you specified. The values of each coordinate in the rectangle are measured in points.
> Do not set the frame if the transform property applies a rotation transform that is not a multiple of 90 degrees.
> For more information about the relationship between the frame, bounds, anchorPoint and position properties, see Core Animation Programming Guide.
> 
----
#### For Export

     UGCAVBuilder *builder = [UGCAVBuilder builderWithTimeLine:self.timeLine];
     builder.settings.preferredVideoSize = CGSizeMake(1280, 720);
     [builder buildComposition:^(AVComposition *composition) {
     [self exportWithComposition:composition andVideoComposition:builder.videoComposition andAnimationTool:[builder makeAnimationTool]];
     }];
     
---      
## How to use UGCAVAssetExportSession
++**Example**:++

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                             [NSString stringWithFormat:@"FinalVideo-%d.mp4",arc4random() % 10000000]];
    UGCAVAssetExportSession *exporter = [UGCAVAssetExportSession exportSessionWithAsset:composition];
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