#include <metal_stdlib>
using namespace metal;

// Existing shader functions may be here

// Optimized MultiClass processing function with more efficient edge detection
kernel void processMultiClass(texture2d<float, access::read> inputTexture [[texture(0)]],
                           texture2d<float, access::write> outputTexture [[texture(1)]],
                           const device uint8_t* categoryMask [[buffer(0)]],
                           const device int& width [[buffer(1)]],
                           uint2 gid [[thread_position_in_grid]]) {
    
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }
    
    const int y = gid.y;
    const int x = gid.x;
    const int index = y * width + x;
    
    // Read the segmentation class
    uint8_t segmentClass = categoryMask[index];
    
    // Read the original pixel color
    float4 originalColor = inputTexture.read(gid);
    
    // Start with the original color
    float4 outputColor = originalColor;
    
    // Process according to segmentation class
    // Class IDs based on the model documentation
    const uint8_t BACKGROUND = 0;
    const uint8_t HAIR = 1;
    const uint8_t SKIN = 2;
    const uint8_t LIPS = 3;
    const uint8_t EYES = 4;
    const uint8_t EYEBROWS = 5;
    
    // Skip processing for background pixels to improve performance
    if (segmentClass == BACKGROUND) {
        outputTexture.write(originalColor, gid);
        return;
    }
    
    // More efficient edge detection - only check 4 neighbors instead of 8
    // This provides similar quality with better performance
    bool isEdge = false;
    
    // Check only direct neighbors (left, right, top, bottom)
    // Check left neighbor if not at left edge
    if (x > 0) {
        int neighborIndex = y * width + (x - 1);
        if (categoryMask[neighborIndex] != segmentClass) {
            isEdge = true;
        }
    }
    
    // Check right neighbor if not at right edge
    if (!isEdge && x < width - 1) {
        int neighborIndex = y * width + (x + 1);
        if (categoryMask[neighborIndex] != segmentClass) {
            isEdge = true;
        }
    }
    
    // Check top neighbor if not at top edge
    if (!isEdge && y > 0) {
        int neighborIndex = (y - 1) * width + x;
        if (categoryMask[neighborIndex] != segmentClass) {
            isEdge = true;
        }
    }
    
    // Check bottom neighbor if not at bottom edge
    if (!isEdge && y < inputTexture.get_height() - 1) {
        int neighborIndex = (y + 1) * width + x;
        if (categoryMask[neighborIndex] != segmentClass) {
            isEdge = true;
        }
    }
    
    // Apply visualizations based on the class
    switch (segmentClass) {
        case HAIR:
            // Highlight hair with a reddish outline
            if (isEdge) {
                outputColor = float4(1.0, 0.2, 0.2, 1.0);  // Red outline
            } else {
                // Slight enhancement of original hair color for better visibility
                outputColor = float4(originalColor.r * 1.05, originalColor.g, originalColor.b, originalColor.a);
            }
            break;
            
        case SKIN:
            // Highlight skin with a greenish outline
            if (isEdge) {
                outputColor = float4(0.2, 1.0, 0.2, 1.0);  // Green outline
            }
            break;
            
        case LIPS:
            // Highlight lips with a purplish outline
            if (isEdge) {
                outputColor = float4(1.0, 0.2, 1.0, 1.0);  // Purple outline
            }
            break;
            
        case EYES:
            // Highlight eyes with a yellowish outline
            if (isEdge) {
                outputColor = float4(1.0, 1.0, 0.2, 1.0);  // Yellow outline
            }
            break;
            
        case EYEBROWS:
            // Highlight eyebrows with a blue outline
            if (isEdge) {
                outputColor = float4(0.2, 0.2, 1.0, 1.0);  // Blue outline
            }
            break;
    }
    
    outputTexture.write(outputColor, gid);
} 