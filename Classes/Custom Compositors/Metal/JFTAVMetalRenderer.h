//
//  JFTAVMetalRenderer.h
//  JFTAVBuilder
//
//  Created by Metal optimization for memory management
//  Replaces CIContext to solve memory leak issues
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, JFTAVMetalFilterType) {
    JFTAVMetalFilterTypePassthrough,    // No filter
    JFTAVMetalFilterTypeBrightness,     // Brightness adjustment
    JFTAVMetalFilterTypeContrast,       // Contrast adjustment
    JFTAVMetalFilterTypeSaturation,     // Saturation adjustment
    JFTAVMetalFilterTypeColorLUT,       // 3D LUT color grading
    JFTAVMetalFilterTypeDissolve,       // Dissolve transition
};

@interface JFTAVMetalRenderer : NSObject

/**
 Creates a Metal renderer with specified device
 @param device Metal device, if nil will use default device
 */
- (instancetype)initWithDevice:(nullable id<MTLDevice>)device;

/**
 Renders a source pixel buffer with optional filter to destination buffer
 @param sourcePixelBuffer Source CVPixelBuffer
 @param destinationPixelBuffer Destination CVPixelBuffer (must be pre-allocated)
 @param filterType Type of filter to apply
 @param parameters Filter parameters (e.g., @{@"brightness": @(0.2)})
 @param transform CGAffineTransform to apply
 @return YES if rendering succeeded
 */
- (BOOL)renderPixelBuffer:(CVPixelBufferRef)sourcePixelBuffer
       toDestinationBuffer:(CVPixelBufferRef)destinationPixelBuffer
                filterType:(JFTAVMetalFilterType)filterType
                parameters:(nullable NSDictionary *)parameters
                 transform:(CGAffineTransform)transform;

/**
 Renders two pixel buffers with transition effect
 @param foregroundBuffer Foreground pixel buffer
 @param backgroundBuffer Background pixel buffer
 @param destinationBuffer Destination pixel buffer
 @param progress Transition progress (0.0 to 1.0)
 @param foregroundTransform Transform for foreground
 @param backgroundTransform Transform for background
 @return YES if rendering succeeded
 */
- (BOOL)renderTransitionWithForeground:(CVPixelBufferRef)foregroundBuffer
                            background:(CVPixelBufferRef)backgroundBuffer
                       toDestination:(CVPixelBufferRef)destinationBuffer
                              progress:(float)progress
                   foregroundTransform:(CGAffineTransform)foregroundTransform
                   backgroundTransform:(CGAffineTransform)backgroundTransform;

/**
 Clears all cached textures and resources. Call this on memory warning.
 */
- (void)clearCaches;

/**
 Waits for all GPU commands to complete. Call this before releasing resources.
 */
- (void)waitUntilCompleted;

@end

NS_ASSUME_NONNULL_END
