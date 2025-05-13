#include <metal_stdlib>
using namespace metal;

// Basic vertex shader for rendering landmarks
vertex float4 vertexShader(uint vertexID [[vertex_id]],
                          constant float4 *vertices [[buffer(0)]]) {
    return vertices[vertexID];
}

// Basic fragment shader for rendering landmarks
fragment half4 fragmentShader(float4 pos [[position]]) {
    return half4(0.0, 1.0, 0.0, 1.0); // Default to green color
} 