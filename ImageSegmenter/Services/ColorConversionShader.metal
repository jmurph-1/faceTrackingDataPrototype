#include <metal_stdlib>
using namespace metal;

// Reference white point (D65)
constant float3 D65_WHITE_POINT = float3(0.95047, 1.0, 1.08883);

// Convert sRGB to linear RGB
float srgb_to_linear(float channel) {
    if (channel <= 0.04045) {
        return channel / 12.92;
    } else {
        return pow((channel + 0.055) / 1.055, 2.4);
    }
}

// Convert XYZ to Lab helper function
float xyz_to_lab_f(float value) {
    float epsilon = 0.008856;
    float kappa = 903.3;
    
    if (value > epsilon) {
        return pow(value, 1.0/3.0);
    } else {
        return (kappa * value + 16.0) / 116.0;
    }
}

// Convert RGB to Lab in one GPU-accelerated operation
kernel void rgbToLab(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    device const uint8_t* segmentMask [[buffer(0)]],
    constant uint& width [[buffer(1)]],
    constant uint& maskWidth [[buffer(2)]],
    constant uint& maskHeight [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Make sure we're within bounds
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    // Get pixel from input texture (RGBA)
    float4 pixel = inputTexture.read(gid);
    
    // Find corresponding position in the mask (accounting for possible scale differences)
    float scaleX = float(maskWidth) / float(inputTexture.get_width());
    float scaleY = float(maskHeight) / float(inputTexture.get_height());
    
    uint maskX = min(uint(float(gid.x) * scaleX), maskWidth - 1);
    uint maskY = min(uint(float(gid.y) * scaleY), maskHeight - 1);
    uint maskIndex = maskY * width + maskX;
    
    uint8_t segmentClass = segmentMask[maskIndex];
    
    // Only process for skin/hair pixels (optimization)
    if (segmentClass != 1 && segmentClass != 2) { // 1=hair, 2=skin
        outputTexture.write(float4(0, 0, 0, 0), gid);
        return;
    }
    
    // Step 1: Convert RGB to linear RGB
    float3 linearRGB = float3(
        srgb_to_linear(pixel.r),
        srgb_to_linear(pixel.g),
        srgb_to_linear(pixel.b)
    );
    
    // Step 2: RGB to XYZ matrix (sRGB with D65 white point)
    float3x3 rgbToXYZ = float3x3(
        float3(0.4124564, 0.3575761, 0.1804375),
        float3(0.2126729, 0.7151522, 0.0721750),
        float3(0.0193339, 0.1191920, 0.9503041)
    );
    
    float3 xyz = rgbToXYZ * linearRGB;
    
    // Step 3: Normalize XYZ by reference white
    float3 xyzNorm = xyz / D65_WHITE_POINT;
    
    // Step 4: Apply non-linear transformation
    float3 fXYZ = float3(
        xyz_to_lab_f(xyzNorm.x),
        xyz_to_lab_f(xyzNorm.y),
        xyz_to_lab_f(xyzNorm.z)
    );
    
    // Step 5: Calculate Lab values
    float L = 116.0 * fXYZ.y - 16.0;
    float a = 500.0 * (fXYZ.x - fXYZ.y);
    float b = 200.0 * (fXYZ.y - fXYZ.z);
    
    // Write Lab values to output (in the alpha channel we store the segment class)
    outputTexture.write(float4(L, a, b, float(segmentClass)), gid);
} 