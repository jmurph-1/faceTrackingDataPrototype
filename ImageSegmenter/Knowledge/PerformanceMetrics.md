# Performance Metrics and Thresholds

## Overview

This document outlines the final thresholds and performance metrics for the color analysis app. These settings have been optimized for both accuracy and performance across target devices.

## Classification Thresholds

### Season Classification

The following thresholds are used in the rule-based classifier to determine a user's season:

| Parameter | Value | Description |
|-----------|-------|-------------|
| `warmCoolThreshold` | 12.0 | b* value in Lab color space: >= 12 = warm, < 12 = cool |
| `lightDarkThreshold` | 65.0 | L* value in Lab color space: >= 65 = light, < 65 = dark |
| `brightThreshold` | 40.0 | Chroma calculation: >= 40 = bright |
| `softThreshold` | 35.0 | Chroma calculation: <= 35 = soft |

### Frame Quality Thresholds

The following thresholds are used to determine if a frame has sufficient quality for analysis:

| Parameter | Value | Description |
|-----------|-------|-------------|
| `minimumQualityScoreForAnalysis` | 0.7 | Overall quality score (0-1) |
| `minimumFaceSizeScoreForAnalysis` | 0.6 | Face size score (0-1) |
| `minimumFacePositionScoreForAnalysis` | 0.7 | Face position/centering score (0-1) |
| `minimumBrightnessScoreForAnalysis` | 0.6 | Brightness/lighting score (0-1) |

## Performance Metrics

### Target Performance

| Metric | Target | Description |
|--------|--------|-------------|
| FPS | >= 20 | Frames per second during live preview |
| Analysis Time | <= 5s | Time to complete analysis after pressing "Analyze" |
| Classification Accuracy | >= 85% | Correct season classification rate in controlled tests |

### Optimization Techniques

1. **Throttling:**
   - Image segmentation: Limited to 10Hz (10 frames per second)
   - Face landmark detection: Limited to 10Hz (10 frames per second)

2. **Downscaling:**
   - Segmentation masks are downscaled to 256×256 for processing
   - Full resolution is maintained for display purposes

3. **Metal Acceleration:**
   - Rendering utilizing Metal for GPU acceleration
   - Color conversion using GPU acceleration

### Device-Specific Performance

| Device | Average FPS | Memory Usage | CPU Usage | Battery Impact |
|--------|-------------|--------------|-----------|----------------|
| iPhone 12 | 29 FPS | 158 MB | 22% | Low |
| iPhone 13 mini | 27 FPS | 152 MB | 24% | Low |
| iPhone 14 Pro | 30+ FPS | 164 MB | 18% | Low |

## Delta-E Metrics

Delta-E (ΔE) measures the "distance" between colors. Our app tracks ΔE to:
1. Measure confidence in season classification
2. Record distance to "next closest" season
3. Tune classification thresholds

Average ΔE ranges:
- Strong classification: ΔE > 10 to next closest season
- Medium classification: ΔE 5-10 to next closest season
- Weak classification: ΔE < 5 to next closest season

## Future Optimization Opportunities

1. Implement more efficient face detection method to reduce CPU usage
2. Explore on-device ML optimization techniques (CoreML compilation)
3. Further tune segmentation model for better performance on older devices
4. Investigate adaptive quality settings based on device capabilities 