# colorAnalysisApp Technical Documentation

## Overview
colorAnalysisApp Cromio is a mobile application designed to help users discover their perfect color palette based on their natural coloring. The app analyzes a user's personal features and determines their "color season" - a concept from color theory that helps people identify which colors complement their natural appearance best.


## Development Environment
- Xcode 16.3
- Swift 6.1

## Technical Requirements
- iOS 13.0 or later
- Swift 5.0+
- MediaPipe framework integration
- Camera and processing permissions

## Current Implementation

### MediaPipe Image Segmentor
The app leverages MediaPipe's image segmentation functionality to:
- Process real-time camera input
- Identify and segment objects/people within frames
- Apply visual effects based on segmentation masks

Key technical components:
- Real-time segmentation processing
- Background separation
- Foreground highlighting
- Multiple segmentation models with different capabilities
- Model selection via dropdown in the live camera viewer

### MultiClass Segmentation Implementation

#### Overview
The application includes a fully functional MultiClass segmentation renderer that processes and displays different segments of a face from the camera feed. This implementation visualizes facial features such as hair, skin, lips, eyes, and eyebrows, and extracts color data from these regions.

#### Key Features
1. **Facial Feature Highlighting:**
   - Each facial feature is outlined with a distinct color for easy visualization
   - Hair regions highlighted with red outlines
   - Skin regions highlighted with green outlines
   - Lips, eyes, and eyebrows have their own distinct colored outlines

2. **Color Extraction:**
   - Real-time extraction of average color values from hair and skin regions
   - Display of both RGB and HSV color values for each feature
   - Color information displayed as text overlays in the camera view

3. **Technical Implementation:**
   - Uses Metal framework for high-performance GPU-based rendering
   - Implements a custom Metal shader kernel (processMultiClass) for feature outlining
   - Uses efficient pixel processing to analyze color values without impacting performance

#### Implementation Details

1. **MultiClassSegmentedImageRenderer**
   - A dedicated renderer class that processes the multiclass segmentation mask
   - Extracts and calculates accurate color values from segmented regions
   - Exposes a ColorInfo structure containing RGB and HSV values for skin and hair

2. **Metal Shader Processing**
   - Edge detection algorithm to identify and highlight feature boundaries
   - Per-pixel classification and visualization based on segmentation class
   - Optimized for real-time performance on iOS devices

3. **UI Integration**
   - Automatic UI adjustments when the MultiClass model is selected
   - Dynamic labels that display color information in real-time
   - Clean integration with the existing app interface

4. **Performance Considerations**
   - Optimized color extraction to minimize impact on frame rate
   - Efficient memory usage to avoid unnecessary allocations
   - Seamless switching between segmentation models



## Future Enhancements
Potential future improvements for the MultiClass segmentation feature:

1. **Enhanced Color Analysis:**
   - Improved color extraction algorithms for better accuracy in varied lighting conditions
   - Color trend analysis over time
   - Multiple sampling points within each feature region

2. **Advanced Visualization Options:**
   - User-configurable visualization modes (outlines, overlays, etc.)
   - Adjustable color and thickness of feature outlines
   - Ability to isolate specific features for detailed analysis

3. **Data Export:**
   - Option to save color data to files for further analysis
   - Integration with other applications or services via sharing
   - Historical data tracking for color changes over time

## Resources
- [MediaPipe Image Segmenter Documentation](https://ai.google.dev/edge/mediapipe/solutions/vision/image_segmenter/ios)
- [MediaPipe GitHub Repository](https://github.com/google/mediapipe)
