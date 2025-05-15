#include <metal_stdlib>
using namespace metal;

// Optimized texture downsampling using bilinear filtering
kernel void downsampleTexture(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early bounds check
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Calculate scale factors
    const float scaleX = float(inputTexture.get_width()) / float(outputTexture.get_width());
    const float scaleY = float(inputTexture.get_height()) / float(outputTexture.get_height());
    
    // Calculate source coordinates with proper alignment
    const float srcX = (float(gid.x) + 0.5f) * scaleX - 0.5f;
    const float srcY = (float(gid.y) + 0.5f) * scaleY - 0.5f;
    
    // Calculate integer and fractional parts for bilinear interpolation
    const int x0 = max(0, int(floor(srcX)));
    const int y0 = max(0, int(floor(srcY)));
    const int x1 = min(int(inputTexture.get_width()) - 1, x0 + 1);
    const int y1 = min(int(inputTexture.get_height()) - 1, y0 + 1);
    
    const float fracX = srcX - float(x0);
    const float fracY = srcY - float(y0);
    
    // Read the four nearest pixels
    const float4 p00 = inputTexture.read(uint2(x0, y0));
    const float4 p10 = inputTexture.read(uint2(x1, y0));
    const float4 p01 = inputTexture.read(uint2(x0, y1));
    const float4 p11 = inputTexture.read(uint2(x1, y1));
    
    // Bilinear interpolation
    const float4 p0 = mix(p00, p10, fracX);
    const float4 p1 = mix(p01, p11, fracX);
    const float4 result = mix(p0, p1, fracY);
    
    // Write the result
    outputTexture.write(result, gid);
}

// Optimized texture downsampling with box filtering for better quality
kernel void downsampleTextureBox(
    texture2d<float, access::sample> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Early bounds check
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Calculate scale factors
    const float scaleX = float(inputTexture.get_width()) / float(outputTexture.get_width());
    const float scaleY = float(inputTexture.get_height()) / float(outputTexture.get_height());
    
    // Calculate source region for box filtering
    const float left = float(gid.x) * scaleX;
    const float top = float(gid.y) * scaleY;
    const float right = min(left + scaleX, float(inputTexture.get_width()));
    const float bottom = min(top + scaleY, float(inputTexture.get_height()));
    
    // Calculate number of samples
    const int samplesX = max(1, int(ceil(right) - floor(left)));
    const int samplesY = max(1, int(ceil(bottom) - floor(top)));
    const int totalSamples = samplesX * samplesY;
    
    // Accumulate color values
    float4 sum = float4(0.0f);
    
    for (int y = int(floor(top)); y < int(ceil(bottom)); y++) {
        for (int x = int(floor(left)); x < int(ceil(right)); x++) {
            // Calculate weight for partial pixels at the edges
            float weightX = 1.0f;
            float weightY = 1.0f;
            
            if (x == int(floor(left))) {
                weightX = 1.0f - (left - floor(left));
            } else if (x == int(ceil(right)) - 1 && ceil(right) != right) {
                weightX = right - floor(right);
            }
            
            if (y == int(floor(top))) {
                weightY = 1.0f - (top - floor(top));
            } else if (y == int(ceil(bottom)) - 1 && ceil(bottom) != bottom) {
                weightY = bottom - floor(bottom);
            }
            
            const float weight = weightX * weightY;
            sum += inputTexture.read(uint2(x, y)) * weight;
        }
    }
    
    // Normalize and write the result
    outputTexture.write(sum / float(totalSamples), gid);
}
