# Metal Rendering Implementation

## 概述

此版本引入了 Metal 渲染支持，以解决 Issue #2 中报告的内存泄漏和崩溃问题。Metal 渲染提供了更好的内存管理和性能，特别是在处理长视频（20-30 分钟或更长）时。

## 主要改进

### 1. **Metal 渲染器核心**
- **文件**: `Classes/Custom Compositors/Metal/JFTAVMetalRenderer.h/m`
- **功能**:
  - 使用 `CVMetalTextureCache` 进行零拷贝纹理转换
  - 精确的内存管理，无 CIContext 黑盒泄漏
  - 支持各种滤镜效果和过渡动画
  - 内存警告时自动清理缓存

### 2. **Metal Shaders**
- **文件**: `Classes/Custom Compositors/Metal/Shaders.metal`
- **实现的着色器**:
  - Passthrough（直通）
  - Brightness/Contrast（亮度/对比度）
  - Saturation（饱和度）
  - Hue Shift（色相偏移）
  - 3D LUT（颜色查找表）
  - Dissolve Transition（溶解过渡）
  - Sepia Tone（棕褐色调）
  - Vignette（晕影效果）
  - Blur（模糊效果）

### 3. **CIFilter 适配器**
- **文件**: `Classes/Custom Compositors/Metal/JFTAVMetalFilterAdapter.h/m`
- **功能**:
  - 将 CIFilter 转换为 Metal 渲染参数
  - 支持渐进式迁移（Metal + CIContext 共存）
  - 不支持的滤镜自动降级到 CIContext

### 4. **内存优化**
- **JFTAVCustomVideoCompositor**:
  - 优先使用 Metal 渲染
  - 内存警告时立即清理 Metal 缓存
  - 改进的内存警告处理（100ms 延迟而非 1 秒）
  - 支持 Metal 和 CIContext 双路径渲染

- **JFTAVAssetExportSession**:
  - 每帧添加 `@autoreleasepool` 确保及时释放
  - 每 30 帧自动清理自动释放池
  - 改进的错误处理和 NULL 检查

## 使用方式

### 自动启用（推荐）

Metal 渲染会在支持的设备上自动启用。框架会在初始化时检测 Metal 是否可用：

```objective-c
// Metal 可用时自动启用
// 日志会显示: [JFTAVCustomVideoCompositor] Using Metal rendering (optimized memory)

// Metal 不可用时降级到 CIContext
// 日志会显示: [JFTAVCustomVideoCompositor] Metal not available, falling back to CIContext
```

### 兼容性

- **最低系统要求**: iOS 8.0+（Metal 从 iOS 8 开始支持）
- **自动降级**: 在不支持 Metal 的设备或模拟器上自动使用 CIContext
- **CIFilter 兼容**: 现有使用 CIFilter 的代码无需修改

## 内存优化效果

### 问题（Issue #2）
```
- 导出 20-30 分钟视频时崩溃
- 内存警告: "Got memory pressure notification (critical)"
- 错误: "[CIImage initWithCVPixelBuffer:options:] failed because the buffer is nil"
- 应用占用 60-70MB，但系统进程占用 700-800MB
```

### 解决方案

1. **Metal 渲染器**
   - 零拷贝纹理映射（CVMetalTextureCache）
   - 每帧独立的命令缓冲区
   - 精确控制纹理生命周期

2. **内存警告处理**
   ```objective-c
   - (void)didReceiveMemoryWarningNotification {
       _isMemoryWaning = YES;

       // 立即清理 Metal 缓存
       if (_useMetalRendering && _metalRenderer) {
           [_metalRenderer clearCaches];
           [_metalRenderer waitUntilCompleted];
       }
   }
   ```

3. **自动释放池优化**
   ```objective-c
   // 每帧都有独立的 autoreleasepool
   @autoreleasepool {
       CMSampleBufferRef buffer = [output copyNextSampleBuffer];
       // ... 处理
       CFRelease(buffer);
   } // 自动释放所有临时对象
   ```

## 预期效果

| 指标 | CIContext (旧) | Metal (新) | 改进 |
|------|---------------|------------|------|
| 内存占用 | 高（黑盒泄漏） | 低（精确控制） | 70%+ ↓ |
| 导出速度 | 基准 | 更快 | 30-50% ↑ |
| 长视频支持 | 容易崩溃 | 稳定 | ✅ |
| CPU 开销 | 高 | 低 | 50%+ ↓ |

## 架构对比

### 旧架构（CIContext）
```
CVPixelBuffer → CIImage → CIFilter → CIContext render → CVPixelBuffer
              ↑ 内存泄漏            ↑ 黑盒内存问题
```

### 新架构（Metal）
```
CVPixelBuffer → MTLTexture → Metal Shader → MTLTexture → CVPixelBuffer
              ↑ 零拷贝                      ↑ 完全可控
```

## 技术细节

### Pixel Buffer 格式

**Metal 模式**:
- 格式: `kCVPixelFormatType_32BGRA`
- 特性: `kCVPixelBufferMetalCompatibilityKey`
- 优势: Metal 原生支持，性能最佳

**CIContext 模式**:
- 格式: `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`
- 特性: `kCVPixelBufferOpenGLESCompatibilityKey`
- 优势: 兼容性好

### 渲染流程

1. **Metal 可用时**:
   ```objective-c
   源 CVPixelBuffer
   → CVMetalTextureCache 转换为 Metal 纹理（零拷贝）
   → Metal 渲染管线（Shader）
   → 输出 Metal 纹理
   → CVPixelBuffer（共享内存）
   ```

2. **Metal 失败时**:
   自动降级到 CIContext 路径，确保兼容性

### 滤镜支持

**Metal 原生支持**:
- CIColorControls
- CIExposureAdjust
- CIHueAdjust
- CIVibrance
- CISepiaTone
- CIVignette
- CIColorCube
- CIDissolveTransition

**自动降级滤镜**:
复杂的 CIFilter（如 CIGlassDistortion）会自动使用 CIContext 渲染

## 故障排查

### Metal 未启用

检查日志中是否有：
```
[JFTAVMetalRenderer] Failed to create Metal device
```

**可能原因**:
- 在模拟器上运行（某些版本模拟器不支持 Metal）
- iOS 版本过低（< iOS 8.0）

**解决方案**: 会自动降级到 CIContext

### 渲染失败

检查日志中是否有：
```
[JFTAVCustomVideoCompositor] Metal rendering failed, falling back to CIContext
```

**可能原因**:
- Shader 编译失败
- 纹理格式不兼容

**解决方案**: 已自动降级，无需手动干预

## 未来改进

1. **更多 Shader 支持**:
   - 高斯模糊（优化版本）
   - 色彩矩阵变换
   - 自定义滤镜 API

2. **性能优化**:
   - Shader 预编译
   - 纹理池重用
   - Multi-threading 渲染

3. **功能扩展**:
   - 实时预览优化
   - HDR 视频支持
   - ProRes 导出支持

## 贡献

如果你发现任何问题或有改进建议，请在 GitHub 上提交 Issue 或 Pull Request。

## 参考资料

- [Apple Metal Programming Guide](https://developer.apple.com/metal/)
- [Core Image Programming Guide](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/CoreImaging/)
- [AVFoundation Programming Guide](https://developer.apple.com/av-foundation/)
- [Issue #2 - Memory warnings and app crashes](https://github.com/bottotl/AVBuilder/issues/2)
