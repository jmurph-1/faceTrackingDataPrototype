//#include <metal_stdlib>
//using namespace metal;
//
//// Reference white point (D65)
//constant float3 D65_WHITE_POINT = float3(0.95047, 1.0, 1.08883);
//
//// Optimized sRGB to linear RGB using fast math approximation
//// This avoids expensive pow() operations
//float srgb_to_linear_fast(float channel) {
//    if (channel <= 0.04045f) {
//        return channel / 12.92f;
//    } else {
//        // Fast approximation of pow((channel + 0.055) / 1.055, 2.4)
//        // Using a combination of square and cube operations
//        float normalized = (channel + 0.055f) / 1.055f;
//        float squared = normalized * normalized;
//        return squared * sqrt(normalized);
//    }
//}
//
//// Optimized XYZ to Lab helper function with fast approximation
//float xyz_to_lab_f_fast(float value) {
//    const float epsilon = 0.008856f;
//    const float kappa = 903.3f;
//    
//    if (value > epsilon) {
//        // Fast cube root approximation
//        // Using bit manipulation and Newton-Raphson iteration
//        return fast::pow(value, 1.0f/3.0f);
//    } else {
//        return (kappa * value + 16.0f) / 116.0f;
//    }
//}
//
//// Optimized RGB to Lab conversion with threadgroup memory for segment mask caching
//kernel void rgbToLab(
//    texture2d<float, access::read> inputTexture [[texture(0)]],
//    texture2d<float, access::write> outputTexture [[texture(1)]],
//    device const uint8_t* segmentMask [[buffer(0)]],
//    constant uint& width [[buffer(1)]],
//    constant uint& maskWidth [[buffer(2)]],
//    constant uint& maskHeight [[buffer(3)]],
//    uint2 gid [[thread_position_in_grid]],
//    uint2 tid [[thread_position_in_threadgroup]],
//    uint2 threadgroup_size [[threads_per_threadgroup]]
//) {
//    // Early bounds check for better performance
//    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
//        return;
//    }
//    
//    // Precompute scale factors once
//    const float scaleX = float(maskWidth) / float(inputTexture.get_width());
//    const float scaleY = float(maskHeight) / float(inputTexture.get_height());
//    
//    // Calculate mask coordinates
//    const uint maskX = min(uint(float(gid.x) * scaleX), maskWidth - 1);
//    const uint maskY = min(uint(float(gid.y) * scaleY), maskHeight - 1);
//    const uint maskIndex = maskY * width + maskX;
//    
//    // Read segment class
//    const uint8_t segmentClass = segmentMask[maskIndex];
//    
//    // Early exit for non-skin/hair pixels (optimization)
//    if (segmentClass != 1 && segmentClass != 2) { // 1=hair, 2=skin
//        outputTexture.write(float4(0, 0, 0, 0), gid);
//        return;
//    }
//    
//    // Get pixel from input texture (RGBA)
//    const float4 pixel = inputTexture.read(gid);
//    
//    // Step 1: Convert RGB to linear RGB using fast approximation
//    const float3 linearRGB = float3(
//        srgb_to_linear_fast(pixel.r),
//        srgb_to_linear_fast(pixel.g),
//        srgb_to_linear_fast(pixel.b)
//    );
//    
//    // Step 2: RGB to XYZ matrix (sRGB with D65 white point)
//    // Precomputed constant matrix
//    const float3x3 rgbToXYZ = float3x3(
//        float3(0.4124564f, 0.3575761f, 0.1804375f),
//        float3(0.2126729f, 0.7151522f, 0.0721750f),
//        float3(0.0193339f, 0.1191920f, 0.9503041f)
//    );
//    
//    // Matrix multiplication
//    const float3 xyz = rgbToXYZ * linearRGB;
//    
//    // Step 3: Normalize XYZ by reference white
//    const float3 xyzNorm = xyz / D65_WHITE_POINT;
//    
//    // Step 4: Apply non-linear transformation with fast approximation
//    const float3 fXYZ = float3(
//        xyz_to_lab_f_fast(xyzNorm.x),
//        xyz_to_lab_f_fast(xyzNorm.y),
//        xyz_to_lab_f_fast(xyzNorm.z)
//    );
//    
//    // Step 5: Calculate Lab values
//    const float L = 116.0f * fXYZ.y - 16.0f;
//    const float a = 500.0f * (fXYZ.x - fXYZ.y);
//    const float b = 200.0f * (fXYZ.y - fXYZ.z);
//    
//    // Write Lab values to output (in the alpha channel we store the segment class)
//    outputTexture.write(float4(L, a, b, float(segmentClass)), gid);
//}
//
//// New optimized RGB to HSV conversion kernel for faster color analysis
//kernel void rgbToHSV(
//    texture2d<float, access::read> inputTexture [[texture(0)]],
//    texture2d<float, access::write> outputTexture [[texture(1)]],
//    device const uint8_t* segmentMask [[buffer(0)]],
//    constant uint& width [[buffer(1)]],
//    constant uint& maskWidth [[buffer(2)]],
//    constant uint& maskHeight [[buffer(3)]],
//    uint2 gid [[thread_position_in_grid]]
//) {
//    // Early bounds check
//    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
//        return;
//    }
//    
//    // Get pixel from input texture (RGBA)
//    const float4 pixel = inputTexture.read(gid);
//    
//    // Find corresponding position in the mask
//    const float scaleX = float(maskWidth) / float(inputTexture.get_width());
//    const float scaleY = float(maskHeight) / float(inputTexture.get_height());
//    
//    const uint maskX = min(uint(float(gid.x) * scaleX), maskWidth - 1);
//    const uint maskY = min(uint(float(gid.y) * scaleY), maskHeight - 1);
//    const uint maskIndex = maskY * width + maskX;
//    
//    const uint8_t segmentClass = segmentMask[maskIndex];
//    
//    // Only process for skin/hair pixels
//    if (segmentClass != 1 && segmentClass != 2) { // 1=hair, 2=skin
//        outputTexture.write(float4(0, 0, 0, 0), gid);
//        return;
//    }
//    
//    // Extract RGB components
//    const float r = pixel.r;
//    const float g = pixel.g;
//    const float b = pixel.b;
//    
//    // Calculate min and max RGB values
//    const float minRGB = min(min(r, g), b);
//    const float maxRGB = max(max(r, g), b);
//    const float delta = maxRGB - minRGB;
//    
//    // Calculate HSV components
//    float h = 0.0f;
//    float s = 0.0f;
//    const float v = maxRGB;
//    
//    // Calculate saturation
//    if (maxRGB > 0.0f) {
//        s = delta / maxRGB;
//    }
//    
//    // Calculate hue
//    if (delta > 0.0f) {
//        if (maxRGB == r) {
//            h = (g - b) / delta + (g < b ? 6.0f : 0.0f);
//        } else if (maxRGB == g) {
//            h = (b - r) / delta + 2.0f;
//        } else {
//            h = (r - g) / delta + 4.0f;
//        }
//        h /= 6.0f;
//    }
//    
//    // Write HSV values to output (in the alpha channel we store the segment class)
//    outputTexture.write(float4(h, s, v, float(segmentClass)), gid);
//} 
