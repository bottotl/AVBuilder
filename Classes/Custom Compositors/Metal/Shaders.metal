//
//  Shaders.metal
//  JFTAVBuilder
//
//  Metal shaders for video filtering and compositing
//

#include <metal_stdlib>
using namespace metal;

// Vertex shader input/output structure
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Vertex shader - transforms vertices to normalized device coordinates
vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                               constant VertexIn *vertices [[buffer(0)]]) {
    VertexOut out;
    VertexIn in = vertices[vertexID];
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Passthrough Fragment Shader

fragment float4 passthroughFragment(VertexOut in [[stage_in]],
                                    texture2d<float> colorTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);
    return color;
}

// MARK: - Brightness and Contrast Fragment Shader

fragment float4 brightnessContrastFragment(VertexOut in [[stage_in]],
                                           texture2d<float> colorTexture [[texture(0)]],
                                           constant float2 &params [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    float brightness = params.x;  // -1.0 to 1.0
    float contrast = params.y;     // 0.0 to 2.0, 1.0 is normal

    // Apply brightness
    color.rgb += brightness;

    // Apply contrast
    color.rgb = ((color.rgb - 0.5) * contrast) + 0.5;

    // Clamp to valid range
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    return color;
}

// MARK: - Saturation Fragment Shader

fragment float4 saturationFragment(VertexOut in [[stage_in]],
                                   texture2d<float> colorTexture [[texture(0)]],
                                   constant float &saturation [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Calculate luminance
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));

    // Interpolate between grayscale and original color based on saturation
    color.rgb = mix(float3(luminance), color.rgb, saturation);

    return color;
}

// MARK: - Hue Shift Fragment Shader

fragment float4 hueShiftFragment(VertexOut in [[stage_in]],
                                 texture2d<float> colorTexture [[texture(0)]],
                                 constant float &hueShift [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // RGB to HSV conversion
    float maxVal = max(max(color.r, color.g), color.b);
    float minVal = min(min(color.r, color.g), color.b);
    float delta = maxVal - minVal;

    float hue = 0.0;
    if (delta > 0.0) {
        if (maxVal == color.r) {
            hue = (color.g - color.b) / delta;
        } else if (maxVal == color.g) {
            hue = 2.0 + (color.b - color.r) / delta;
        } else {
            hue = 4.0 + (color.r - color.g) / delta;
        }
        hue *= 60.0;
        if (hue < 0.0) hue += 360.0;
    }

    // Apply hue shift
    hue = fmod(hue + hueShift, 360.0);

    float saturation = (maxVal > 0.0) ? (delta / maxVal) : 0.0;
    float value = maxVal;

    // HSV to RGB conversion
    float c = value * saturation;
    float x = c * (1.0 - abs(fmod(hue / 60.0, 2.0) - 1.0));
    float m = value - c;

    float3 rgb;
    if (hue < 60.0) {
        rgb = float3(c, x, 0.0);
    } else if (hue < 120.0) {
        rgb = float3(x, c, 0.0);
    } else if (hue < 180.0) {
        rgb = float3(0.0, c, x);
    } else if (hue < 240.0) {
        rgb = float3(0.0, x, c);
    } else if (hue < 300.0) {
        rgb = float3(x, 0.0, c);
    } else {
        rgb = float3(c, 0.0, x);
    }

    color.rgb = rgb + m;

    return color;
}

// MARK: - 3D LUT Fragment Shader

fragment float4 lutFragment(VertexOut in [[stage_in]],
                            texture2d<float> colorTexture [[texture(0)]],
                            texture3d<float> lutTexture [[texture(1)]],
                            constant float &intensity [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    constexpr sampler lutSampler(mag_filter::linear, min_filter::linear);

    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Sample the 3D LUT
    float3 lutCoord = clamp(color.rgb, 0.0, 1.0);
    float4 lutColor = lutTexture.sample(lutSampler, lutCoord);

    // Mix between original and LUT color based on intensity
    color.rgb = mix(color.rgb, lutColor.rgb, intensity);

    return color;
}

// MARK: - Dissolve Transition Fragment Shader

fragment float4 dissolveFragment(VertexOut in [[stage_in]],
                                 texture2d<float> foregroundTexture [[texture(0)]],
                                 texture2d<float> backgroundTexture [[texture(1)]],
                                 constant float &progress [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 foreground = foregroundTexture.sample(textureSampler, in.texCoord);
    float4 background = backgroundTexture.sample(textureSampler, in.texCoord);

    // Simple linear interpolation for dissolve effect
    float4 result = mix(foreground, background, progress);

    return result;
}

// MARK: - Advanced Dissolve with Noise

fragment float4 dissolveNoiseFragment(VertexOut in [[stage_in]],
                                      texture2d<float> foregroundTexture [[texture(0)]],
                                      texture2d<float> backgroundTexture [[texture(1)]],
                                      constant float &progress [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 foreground = foregroundTexture.sample(textureSampler, in.texCoord);
    float4 background = backgroundTexture.sample(textureSampler, in.texCoord);

    // Generate pseudo-random noise based on texture coordinates
    float noise = fract(sin(dot(in.texCoord, float2(12.9898, 78.233))) * 43758.5453);

    // Use noise to create a more organic transition
    float threshold = smoothstep(progress - 0.1, progress + 0.1, noise);

    float4 result = mix(background, foreground, threshold);

    return result;
}

// MARK: - Blur Fragment Shader (Simple Box Blur)

fragment float4 blurFragment(VertexOut in [[stage_in]],
                             texture2d<float> colorTexture [[texture(0)]],
                             constant float &blurRadius [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float2 texelSize = 1.0 / float2(colorTexture.get_width(), colorTexture.get_height());
    float4 color = float4(0.0);
    float totalWeight = 0.0;

    int radius = int(blurRadius);
    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            float2 offset = float2(x, y) * texelSize;
            color += colorTexture.sample(textureSampler, in.texCoord + offset);
            totalWeight += 1.0;
        }
    }

    color /= totalWeight;
    return color;
}

// MARK: - Sepia Tone Fragment Shader

fragment float4 sepiaFragment(VertexOut in [[stage_in]],
                              texture2d<float> colorTexture [[texture(0)]],
                              constant float &intensity [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Sepia tone transformation matrix
    float3 sepia;
    sepia.r = dot(color.rgb, float3(0.393, 0.769, 0.189));
    sepia.g = dot(color.rgb, float3(0.349, 0.686, 0.168));
    sepia.b = dot(color.rgb, float3(0.272, 0.534, 0.131));

    // Mix between original and sepia based on intensity
    color.rgb = mix(color.rgb, sepia, intensity);

    return color;
}

// MARK: - Vignette Fragment Shader

fragment float4 vignetteFragment(VertexOut in [[stage_in]],
                                 texture2d<float> colorTexture [[texture(0)]],
                                 constant float2 &params [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    float intensity = params.x;  // Vignette intensity
    float radius = params.y;     // Vignette radius

    // Calculate distance from center
    float2 center = float2(0.5, 0.5);
    float dist = distance(in.texCoord, center);

    // Apply vignette effect
    float vignette = smoothstep(radius, radius - 0.3, dist);
    color.rgb *= mix(1.0, vignette, intensity);

    return color;
}
