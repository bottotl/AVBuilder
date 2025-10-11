//
//  JFTAVMetalFilterAdapter.m
//  JFTAVBuilder
//
//  Adapter to convert CIFilter to Metal rendering parameters
//

#import "JFTAVMetalFilterAdapter.h"

@implementation JFTAVMetalFilterAdapter

+ (BOOL)canRenderFilterWithMetal:(CIFilter *)filter {
    if (!filter) {
        // No filter means passthrough, which Metal can handle
        return YES;
    }

    NSString *filterName = filter.name;

    // List of CIFilter names that we can render with Metal
    static NSSet *supportedFilters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportedFilters = [NSSet setWithArray:@[
            // Color adjustment filters
            @"CIColorControls",
            @"CIExposureAdjust",
            @"CIGammaAdjust",
            @"CIHueAdjust",
            @"CIVibrance",

            // Stylize filters
            @"CISepiaTone",
            @"CIVignette",

            // Blur filters
            @"CIBoxBlur",
            @"CIGaussianBlur",

            // Color effects
            @"CIColorCube",
            @"CIColorCubeWithColorSpace",

            // Transition effects
            @"CIDissolveTransition",
        ]];
    });

    return [supportedFilters containsObject:filterName];
}

+ (BOOL)convertFilter:(CIFilter *)filter
    toMetalFilterType:(JFTAVMetalFilterType *)outFilterType
           parameters:(NSDictionary **)outParameters {

    if (!filter) {
        // No filter = passthrough
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypePassthrough;
        if (outParameters) *outParameters = nil;
        return YES;
    }

    NSString *filterName = filter.name;
    NSMutableDictionary *params = [NSMutableDictionary dictionary];

    // CIColorControls - brightness, saturation, contrast
    if ([filterName isEqualToString:@"CIColorControls"]) {
        NSNumber *brightness = [filter valueForKey:kCIInputBrightnessKey];
        NSNumber *saturation = [filter valueForKey:kCIInputSaturationKey];
        NSNumber *contrast = [filter valueForKey:kCIInputContrastKey];

        if (saturation && saturation.floatValue != 1.0) {
            if (outFilterType) *outFilterType = JFTAVMetalFilterTypeSaturation;
            params[@"saturation"] = saturation;
        } else {
            if (outFilterType) *outFilterType = JFTAVMetalFilterTypeBrightness;
            params[@"brightness"] = brightness ?: @(0.0);
            params[@"contrast"] = contrast ?: @(1.0);
        }

        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CIExposureAdjust - similar to brightness
    if ([filterName isEqualToString:@"CIExposureAdjust"]) {
        NSNumber *exposure = [filter valueForKey:kCIInputEVKey];
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeBrightness;
        params[@"brightness"] = @(exposure.floatValue * 0.5); // Scale exposure to brightness range
        params[@"contrast"] = @(1.0);
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CIHueAdjust
    if ([filterName isEqualToString:@"CIHueAdjust"]) {
        NSNumber *angle = [filter valueForKey:kCIInputAngleKey];
        // Convert radians to degrees
        float degrees = angle.floatValue * 180.0 / M_PI;
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeBrightness; // Use brightness as fallback
        params[@"hueShift"] = @(degrees);
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CIVibrance - similar to saturation
    if ([filterName isEqualToString:@"CIVibrance"]) {
        NSNumber *amount = [filter valueForKey:@"inputAmount"];
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeSaturation;
        params[@"saturation"] = @(1.0 + amount.floatValue);
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CISepiaTone
    if ([filterName isEqualToString:@"CISepiaTone"]) {
        NSNumber *intensity = [filter valueForKey:kCIInputIntensityKey];
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeBrightness; // Use custom sepia shader
        params[@"sepiaIntensity"] = intensity ?: @(1.0);
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CIVignette
    if ([filterName isEqualToString:@"CIVignette"]) {
        NSNumber *intensity = [filter valueForKey:kCIInputIntensityKey];
        NSNumber *radius = [filter valueForKey:kCIInputRadiusKey];
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeBrightness; // Use custom vignette shader
        params[@"vignetteIntensity"] = intensity ?: @(0.0);
        params[@"vignetteRadius"] = radius ?: @(1.0);
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CIColorCube and CIColorCubeWithColorSpace
    if ([filterName isEqualToString:@"CIColorCube"] ||
        [filterName isEqualToString:@"CIColorCubeWithColorSpace"]) {
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeColorLUT;
        // LUT data would need to be extracted and converted to Metal texture
        // This is more complex and might need additional implementation
        NSData *cubeData = [filter valueForKey:@"inputCubeData"];
        NSNumber *cubeDimension = [filter valueForKey:@"inputCubeDimension"];
        params[@"lutData"] = cubeData;
        params[@"lutDimension"] = cubeDimension;
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CIDissolveTransition
    if ([filterName isEqualToString:@"CIDissolveTransition"]) {
        NSNumber *time = [filter valueForKey:kCIInputTimeKey];
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeDissolve;
        params[@"progress"] = time ?: @(0.0);
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // CIBoxBlur, CIGaussianBlur
    if ([filterName isEqualToString:@"CIBoxBlur"] ||
        [filterName isEqualToString:@"CIGaussianBlur"]) {
        NSNumber *radius = [filter valueForKey:kCIInputRadiusKey];
        if (outFilterType) *outFilterType = JFTAVMetalFilterTypeBrightness; // Use custom blur shader
        params[@"blurRadius"] = radius ?: @(10.0);
        if (outParameters) *outParameters = [params copy];
        return YES;
    }

    // Unsupported filter
    return NO;
}

+ (NSDictionary *)parametersFromFilter:(CIFilter *)filter {
    if (!filter) return nil;

    NSMutableDictionary *params = [NSMutableDictionary dictionary];

    // Extract all input keys and their values
    NSArray *inputKeys = [filter inputKeys];
    for (NSString *key in inputKeys) {
        if ([key isEqualToString:kCIInputImageKey]) {
            continue; // Skip image input
        }

        id value = [filter valueForKey:key];
        if (value) {
            params[key] = value;
        }
    }

    return [params copy];
}

@end
