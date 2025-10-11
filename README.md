# JFTAVBuilder

![示意图](http://wx3.sinaimg.cn/large/6b5f103fgy1fij4k3d1j8j20o00fnq5n.jpg)

一个强大的 iOS 视频编辑框架，支持视频合成、转场效果、滤镜、水印、字幕等功能。

## Features

- ✅ 支持多个视频片段合成
- ✅ 视频转场效果（淡入淡出等）
- ✅ 滤镜支持（LUT 色彩查找表）
- ✅ 背景音乐混音
- ✅ 水印和字幕叠加
- ✅ 自动处理视频旋转（横屏/竖屏/各种角度）
- ✅ Metal 渲染支持，优化内存管理和性能
- ✅ 自定义视频导出参数（分辨率、码率等）

## Recent Updates

### v1.0.1 (2025-01-11)
- 🐛 修复添加新视频时之前片段丢失的问题
- 🐛 修复视频旋转处理，支持所有视频方向
- ⚡️ Metal 渲染器智能回退，确保旋转正确性
- 🎨 改进视频列表 UI 和交互体验

## How to use

### 创建 Time Line

#### Create video

```objc
JFTAVVideoMediaItem *item = [[JFTAVVideoMediaItem alloc] initWithURL:url];
// 或者从 AVAsset 创建
JFTAVVideoMediaItem *item = [[JFTAVVideoMediaItem alloc] initWithAsset:asset];

// 添加滤镜（使用 LUT）
item.filter = [CIFilter colorCubeWithColrLUTImageNamed:@"lut_name" dimension:64];

// 设置转场效果
item.transition.transitionDuration = CMTimeMakeWithSeconds(1, 30);
item.transition.type = JFTAVVideoMediaItemTransitionTypeFadeInAndFadeOut;
```

#### Create music

```objc
timeLine.music = [[JFTAVMusicMediaItem alloc] initWithURL:musicUrl];
timeLine.music.mixRate = 0.3; // 音乐音量占比（0.0-1.0）
```

#### Create Overlay

```objc
timeLine.nameOverlay = [[JFTAVOverlayItem alloc] initWithName:@"your name"
                                              andOverlayImage:[UIImage imageNamed:@"overlay_white"]];
```

#### Create Subtitle

```objc
timeLine.subtitle = [[JFTAVSubtitlesItem alloc] initWithSubtitles:@"字幕文本"];
```

### Use Builder

**Example:**

```objc
JFTAVBuilder *builder = [JFTAVBuilder builderWithTimeLine:self.timeLine];
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
```
---

### For Playback

#### 1. 设置视频尺寸（默认 540×960）

```objc
builder.settings.preferredVideoSize = CGSizeMake(1280, 720);
```

#### 2. 生成 composition

```objc
[builder buildComposition:^(AVMutableComposition *composition) {
    // 处理 composition
}];
```

#### 3. 从 Builder 中获取数据

```objc
builder.videoComposition
builder.audioMix
[builder createAnimationLayer]
```

> 创建 animation layer 的方法在 `JFTAVBuilder+Play` 分类中

#### 4. 创建 PlayerItem

```objc
AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:composition];
playerItem.videoComposition = builder.videoComposition;
playerItem.audioMix = builder.audioMix;
```

#### 5. 创建 AVSynchronizedLayer（用于展示水印、字幕）

```objc
self.synLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:playerItem];
[self.synLayer addSublayer:self.animationLayer];

[self.playerView.layer addSublayer:self.synLayer];
[self.animationLayer setAffineTransform:[JFTAVBuilder scaleTransformMaker:CGRectMake(0, 0, self.videoComposition.renderSize.width, self.videoComposition.renderSize.height) andPlayerRect:self.playerView.frame]];
```

**为什么要对 animation layer 进行缩放？**

1. 水印的大小应该是相对于视频的尺寸而言的
2. 视频在播放的时候大小随时可能会改变

⚠️ **注意：加了 transform 以后不可以修改 frame，你应该修改 position 和 bounds**

```objc
self.animationLayer.position = CGPointMake(self.playerView.bounds.size.width / 2,
                                           self.playerView.bounds.size.height / 2);
```

---

### For Export

```objc
JFTAVBuilder *builder = [JFTAVBuilder builderWithTimeLine:self.timeLine];
builder.settings.preferredVideoSize = CGSizeMake(1280, 720);
[builder buildComposition:^(AVComposition *composition) {
    [self exportWithComposition:composition
             andVideoComposition:builder.videoComposition
                andAnimationTool:[builder makeAnimationTool]];
}];
```

---

## How to use JFTAVAssetExportSession

自定义导出会话，支持更精细的导出参数控制。

**Example:**

```objc
NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
NSString *documentsDirectory = [paths objectAtIndex:0];
NSString *myPathDocs = [documentsDirectory stringByAppendingPathComponent:
                        [NSString stringWithFormat:@"FinalVideo-%d.mp4", arc4random() % 10000000]];

JFTAVAssetExportSession *exporter = [JFTAVAssetExportSession exportSessionWithAsset:composition];
videoComposition.animationTool = animationTool;
exporter.videoComposition = videoComposition;
exporter.outputURL = [NSURL fileURLWithPath:myPathDocs];
exporter.videoSettings.dataBitRate = 1600;
exporter.videoSettings.preferredVideoSize = CGSizeMake(960, 540);
exporter.timeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(1, 1), CMTimeMakeWithSeconds(2, 1));

[exporter exportAsynchronouslyWithCompletionHandler:^{
    if (!exporter.error) {
        [self saveVideoToAlbum:[NSURL fileURLWithPath:myPathDocs]];
    } else {
        NSLog(@"%@", exporter.error);
    }
}];
```

---

## Installation

### CocoaPods

```ruby
pod 'JFTAVBuilder'
```

### Manual

将 `Classes` 文件夹拖入你的项目。

---

## Requirements

- iOS 10.0+
- Xcode 12.0+
- Objective-C

---

## Technical Details

### Video Rotation Handling

框架自动处理所有视频方向：
- 横屏视频
- 竖屏视频
- 各种旋转角度（90°, 180°, 270°）

内部使用 `preferredTransform` 和智能缩放算法确保视频正确显示。

### Metal Rendering

- 默认使用 Metal 渲染器以获得更好的性能和内存管理
- 当需要旋转变换时自动回退到 CIContext 确保正确性
- 支持的滤镜类型会使用 Metal 加速

### Memory Management

- Metal 渲染路径优化了内存使用
- 收到内存警告时自动清理纹理缓存
- 使用 autorelease pool 管理临时对象

---

## License

MIT License

---

## Contributing

欢迎提交 Issue 和 Pull Request！

---

## Author

jft0m

---

## Changelog

### v1.0.1 (2025-01-11)
- 修复添加新视频时之前片段丢失的问题
- 修复视频旋转处理，支持所有视频方向
- Metal 渲染器智能回退，确保旋转正确性
- 改进视频列表 UI 和交互体验

### v1.0.0
- 初始版本发布
- 支持视频合成、转场、滤镜、水印、字幕
- Metal 渲染支持