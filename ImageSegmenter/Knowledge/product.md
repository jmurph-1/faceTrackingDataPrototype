# colorAnalysisApp Technical Documentation

## Overview
colorAnalysisApp Cromio is a mobile application designed to help users discover their perfect color palette based on their natural coloring. The app analyzes a user's personal features and determines their "color season" - a concept from color theory that helps people identify which colors complement their natural appearance best.

## App Goals
The primary goal of colorAnalysisApp is to help users identify their ideal color palette based on their natural features. The app focuses on these key objectives:

* **Advanced Color Analysis**: Utilize state-of-the-art technology, including machine learning and computer vision, to accurately identify key indicators—such as skin undertone, hair color, and eye color—that determine a user's seasonal color category within the 12-season framework. This goal includes developing a robust and precise algorithm that can handle variations in lighting, background, and user input to ensure consistent and reliable results.

* **Personalized Seasonal Results**: Provide users with a customized seasonal color profile based on the analysis. This involves refining the standard characteristics, color palettes, and style recommendations for each of the 12 seasons, offering personalized guidance based on the user's unique features. This may include identifying nuanced differences within a season or recommending subtle shifts in color choices for a more tailored result.

* **Interactive Exploration of Seasons**: Implement a feature that allows users to browse all 12 default seasons, complete with standard details, color palettes, and guidelines. This exploration tool would serve both as an educational resource and as a way for users to understand how their personalized results compare to the broader seasonal framework. It can also help users see the common traits and differences between each season, fostering a deeper understanding of color theory and application.

* **User Experience and Engagement**: Ensure the app offers a seamless, intuitive interface that makes the analysis process straightforward and engaging. This includes clear instructions, immediate feedback, and visually appealing results. Additionally, incorporate features like saving results, sharing with friends, and accessing personalized shopping or style recommendations based on their season.

* **Technical Scalability and Integration**: Design the underlying architecture to be flexible and scalable, allowing for future enhancements like adding new features, supporting more detailed analyses, or integrating with other platforms (e.g., shopping portals or social media). This ensures the app remains relevant and adaptable over time.

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

### Face Tracking Implementation

#### Overview
The application now includes a robust face tracking feature that precisely detects and visualizes facial landmarks in real-time using MediaPipe's Face Landmarker model. This implementation provides accurate facial feature tracking and serves as a foundation for more advanced facial analysis.

#### Key Features
1. **Face Landmark Detection:**
   - Real-time detection of 478 facial landmarks
   - High-precision tracking of key facial features (eyes, lips, nose, face contour)
   - Efficient processing that maintains smooth performance

2. **Mode Selection:**
   - Toggle switch in the UI to alternate between face tracking and image segmentation
   - Mutually exclusive modes to optimize performance and prevent resource conflicts
   - Clear visual feedback when switching between modes

3. **Landmark Visualization:**
   - Intuitive visualization with colored dots representing different facial regions
   - Red dots for face contour, green for eyes, blue for lips, and yellow for other features
   - Optimized rendering that displays a subset of landmarks for better performance

4. **Robust Implementation:**
   - Proper background/foreground handling with app lifecycle management
   - Automatic reinitializing of services when returning from background
   - Thread-safe implementation that prevents UI access from background threads
   - Efficient clearing of landmarks when toggling face tracking off

5. **Performance Optimizations:**
   - Conditional debugging logs to reduce console spam
   - Proper resource management to prevent memory leaks
   - Efficient overlay rendering system for landmark visualization

#### Technical Implementation

1. **MediaPipe Integration:**
   - Uses MediaPipe Face Landmarker task for precise facial feature detection
   - Processes camera frames in real-time with optimized performance
   - Implements appropriate delegate patterns for asynchronous processing

2. **UI Components:**
   - Clean toggle interface for switching between modes
   - Transparent overlay system for visualizing landmarks without affecting the camera preview
   - Dynamic creation and management of landmark dots based on detection results

3. **Architecture Improvements:**
   - Thread-safe property for tracking face detection state
   - Clear separation between segmentation and face tracking services
   - Proper cleanup of resources when switching modes or when app state changes

This face tracking implementation provides a solid foundation for future facial analysis features such as precise color sampling from specific facial regions, emotion detection, and more advanced beauty and cosmetic applications.

## Proposed Video Processing Solution
The new solution leverages Google's MediaPipe framework to significantly improve the accuracy and reliability of color extraction from video. This approach addresses several challenges in color analysis:

### Key Components
1. **MediaPipe Integration**
   * **Face Landmark Detection**: Uses MediaPipe's 478-point face landmark system to precisely track facial features
   * **Image Segmentation**: Employs multi-class segmentation to identify specific regions (hair, face-skin, body-skin)

2. **Advanced Processing Pipeline**
```
Video Input → Frame Extraction → Face Detection → Face Landmark Detection → 
Image Segmentation → Region Identification → Color Sampling → 
Lighting Correction → RGB to LAB Conversion → Temporal Averaging → Final LAB Values
```

3. **Intelligent Region Identification**
   * Uses specific facial landmarks to target optimal sampling areas:
      * Forehead (landmarks 10, 67, 109)
      * Cheeks (landmarks 123, 352)
      * Eyes (landmarks 33, 133, 362, 263)
   * Combines landmarks with segmentation masks to ensure accurate region selection

4. **Lighting Correction Methodology**
   * Reference white point sampling from neutral areas
   * Skin tone normalization using forehead as reference
   * Cross-frame consistency through temporal tracking
   * Adaptive correction based on confidence scores
   * Formula: `Corrected_RGB = Original_RGB * (Reference_RGB / Sampled_Reference_RGB)`

5. **Color Extraction Process**
   * Converts corrected RGB values to LAB color space for perceptual accuracy
   * Implements temporal averaging across 5-10 frames with weighted values
   * Filters outliers to remove noise and improve consistency

6. **Swift Implementation**
   * Uses MediaPipe's iOS SDK with Swift wrappers
   * Implements modular pipeline with Swift's concurrency features
   * Efficient memory management with Swift's ARC

### Benefits of the New Approach
1. **Precision**: Accurate identification of regions of interest using both landmarks and segmentation
2. **Robustness**: Handles variations in lighting and movement through correction and averaging
3. **Efficiency**: Leverages optimized MediaPipe models for mobile performance
4. **Flexibility**: Modular design allows for future enhancements

### Technical Implementation
The solution will be implemented through a `VideoColorProcessor` class with methods to process video frames and extract LAB color values for skin, hair, and eyes, along with confidence scores for the results.

This approach represents a significant advancement over traditional color extraction methods, providing more accurate and consistent results even in challenging lighting conditions or with subject movement.


## Resources
- [MediaPipe Image Segmenter Documentation](https://ai.google.dev/edge/mediapipe/solutions/vision/image_segmenter/ios)
- [MediaPipe GitHub Repository](https://github.com/google/mediapipe)
