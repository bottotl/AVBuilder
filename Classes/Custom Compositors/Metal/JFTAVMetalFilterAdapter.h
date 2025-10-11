//
//  JFTAVMetalFilterAdapter.h
//  JFTAVBuilder
//
//  Adapter to convert CIFilter to Metal rendering parameters
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import "JFTAVMetalRenderer.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Adapter class to convert CIFilter objects to Metal rendering parameters
 This allows gradual migration from CIContext to Metal rendering
 */
@interface JFTAVMetalFilterAdapter : NSObject

/**
 Determines if a CIFilter can be rendered using Metal
 @param filter The CIFilter to check
 @return YES if Metal can render this filter
 */
+ (BOOL)canRenderFilterWithMetal:(nullable CIFilter *)filter;

/**
 Converts a CIFilter to Metal filter type and parameters
 @param filter The CIFilter to convert
 @param outFilterType Output parameter for Metal filter type
 @param outParameters Output parameter for filter parameters dictionary
 @return YES if conversion succeeded
 */
+ (BOOL)convertFilter:(nullable CIFilter *)filter
           toMetalFilterType:(JFTAVMetalFilterType *)outFilterType
                  parameters:(NSDictionary * _Nullable * _Nullable)outParameters;

/**
 Extracts filter parameters from a CIFilter object
 @param filter The CIFilter to extract from
 @return Dictionary of filter parameters
 */
+ (nullable NSDictionary *)parametersFromFilter:(CIFilter *)filter;

@end

NS_ASSUME_NONNULL_END
