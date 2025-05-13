# Video Processing Plan for colorAnalysisApp Using MediaPipe

## Executive Summary

This document outlines a comprehensive plan for implementing video processing in colorAnalysisApp using Google's MediaPipe solutions. The proposed approach leverages MediaPipe's face landmark detection for real-time tracking and strategic screenshot capture, with image segmentation performed as a separate process afterward. This separation optimizes performance while extracting accurate LAB color values for skin, hair, and eyes from video sources and correcting for lighting variations.

## Table of Contents

1. [Current Challenges](#current-challenges)
2. [MediaPipe Solutions Overview](#mediapipe-solutions-overview)
3. [Proposed Workflow](#proposed-workflow)
4. [Implementation Details](#implementation-details)
5. [Lighting Correction Methodology](#lighting-correction-methodology)
6. [Color Extraction Process](#color-extraction-process)
7. [Accuracy Assessment](#accuracy-assessment)
8. [Integration with colorAnalysisApp](#integration-with-colorAnalysisApp)
9. [Limitations and Mitigations](#limitations-and-mitigations)
10. [Conclusion](#conclusion)

## Current Challenges

Extracting accurate color values from video presents several challenges:

1. **Lighting Variations**: Different lighting conditions significantly affect perceived colors
2. **Movement**: Subject movement can cause blur and inconsistent readings
3. **Region Identification**: Accurately identifying skin, hair, and eye regions
4. **Color Space Conversion**: Converting from RGB to LAB color space while preserving accuracy
5. **Temporal Consistency**: Maintaining consistent color readings across video frames
6. **Performance Constraints**: Running multiple ML models simultaneously can degrade user experience

## MediaPipe Solutions Overview

### Image Segmentation

MediaPipe's Image Segmenter provides multi-class segmentation capabilities that can identify:

- Background
- Hair
- Body-skin
- Face-skin
- Clothes
- Accessories

This segmentation works on both single images and continuous video streams. The multi-class selfie segmentation model can precisely isolate the regions of interest (skin, hair) needed for color extraction.

### Face Landmark Detection

MediaPipe's Face Landmarker provides:

- 478 3D face landmarks for precise facial feature tracking
- 52 blendshape scores for facial expressions
- Transformation matrices for spatial relationships

These landmarks enable tracking specific facial points throughout a video, which is crucial for:
- Consistent region identification
- Tracking the same skin/hair areas across frames
- Identifying optimal sampling points for color extraction
- Establishing reference points for lighting correction

## Proposed Workflow

The revised video processing workflow separates real-time face landmark tracking from image segmentation to optimize performance:

```
[Video Input] → [Frame Extraction] → [Face Detection] → [Face Landmark Tracking] → 
[Strategic Screenshot Capture] → [Skin Color Analysis] → [Screenshot Processing] → 
[Image Segmentation] → [Hair/Eye Color Analysis] → [Lighting Correction] → 
[RGB to LAB Conversion] → [Final LAB Values]
```

### Workflow Diagram

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────────┐
│ Video Input │────▶│Frame Extract│────▶│MediaPipe Face Detect│
└─────────────┘     └─────────────┘     └──────────┬──────────┘
                                                   │
                                                   ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────┐
│Strategic        │◀────│Real-time        │◀────│MediaPipe Face Landmk│
│Screenshot       │     │Skin Analysis    │     └──────────┬──────────┘
│Capture          │     └─────────────────┘                │
└───────┬─────────┘                                        │
        │                                                  │
        ▼                                                  ▼
┌───────────────────┐                           ┌─────────────────────┐
│Image Segmentation │                           │Light/Position       │
│(Post-Processing)  │                           │Quality Assessment   │
└───────┬───────────┘                           └─────────────────────┘
        │
        ▼
┌───────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│Hair/Eye Color     │────▶│RGB→LAB Convert  │────▶│Final LAB Values │
│Analysis           │     └─────────────────┘     └─────────────────┘
└───────────────────┘
```

## Implementation Details

### 1. Video Input and Frame Extraction

- Process video at 15-30 fps depending on device capabilities
- Extract key frames for face landmark processing
- Implement frame buffering to handle varying processing times

### 2. Face Detection and Landmark Tracking (Real-time Phase)

- Use MediaPipe Face Landmarker to detect and track facial features in real-time
- Track specific landmarks for:
  - Forehead (landmarks 10, 67, 109)
  - Cheeks (landmarks 123, 352)
  - Nose (landmarks 1, 4, 5)
  - Eyes (landmarks 33, 133, 362, 263)
  - Lips (landmarks 0, 17, 61, 291)
  - Jawline (landmarks 140, 367, 397)
- Use these landmarks to:
  - Provide real-time feedback to guide user positioning
  - Establish reference points for lighting normalization
  - Track consistent regions for skin color sampling
  - Calculate a frame quality score based on:
    - Face positioning (centered, proper size)
    - Lighting conditions
    - Stability (minimal motion blur)
    - Confidence scores of landmark detection

### 3. Strategic Screenshot Capture

- Capture 5-8 high-quality screenshots at strategic moments:
  - When quality score exceeds predetermined threshold
  - At different head angles to capture varied lighting conditions
  - When the face is properly centered and well-lit
  - With minimal motion blur
- Store screenshots in memory for post-processing
- Tag each screenshot with metadata:
  - Head position (angle, orientation)
  - Lighting quality assessment
  - Face landmark positions
  - Timestamp

### 4. Real-time Skin Color Analysis

- While tracking landmarks, perform preliminary skin color analysis:
  - Sample from cheek regions (using landmarks 123, 352)
  - Avoid areas near nose and mouth
  - Collect data across frames with varied head positions
  - Apply temporal averaging for stability

### 5. Post-processing Image Segmentation

- After video capture phase is complete, process the stored screenshots:
  - Apply MediaPipe Image Segmenter with multi-class selfie segmentation model
  - Extract segmentation masks for:
    - Hair (category 1)
    - Body-skin (category 2)
    - Face-skin (category 3)
  - Create binary masks for each region of interest
  - Process in background thread to maintain app responsiveness

### 6. Hair and Eye Color Analysis

- For hair color:
  - Use hair segmentation mask from screenshots
  - Sample from top and sides of head
  - Account for highlights/lowlights with multi-point sampling
  - Compare results across multiple screenshots

- For eye color:
  - Use eye landmarks (33, 133, 362, 263) to locate eye regions
  - Apply additional processing to isolate iris from sclera
  - Sample from multiple screenshots for consistency

### 7. Color Sampling Strategy

For each region of interest:
1. Define sampling grid within the region
2. Extract RGB values from multiple points within the grid
3. Filter outliers to remove noise
4. Calculate weighted average based on confidence scores
5. Compare results across different screenshots

## Lighting Correction Methodology

Lighting correction is crucial for accurate color extraction. The proposed approach uses:

1. **Reference White Point**: 
   - Sample from known neutral areas (e.g., whites of eyes, teeth if visible)
   - Use as reference for white balance correction

2. **Skin Tone Normalization**:
   - Use forehead region as reference point (typically most evenly lit)
   - Calculate illumination correction factor by comparing with expected values

3. **Cross-Frame Consistency**:
   - Compare lighting across different screenshots
   - Use metadata about head position to understand lighting variations

4. **Adaptive Correction**:
   - Adjust correction strength based on confidence scores
   - Apply stronger correction in challenging lighting conditions

### Lighting Correction Formula

```
Corrected_RGB = Original_RGB * (Reference_RGB / Sampled_Reference_RGB)
```

Where:
- Original_RGB: Raw color values from sampling points
- Reference_RGB: Expected RGB values for reference points
- Sampled_Reference_RGB: Actual RGB values from reference points

## Color Extraction Process

### RGB to LAB Conversion

After lighting correction, RGB values are converted to LAB color space:

1. Convert RGB to XYZ color space
2. Convert XYZ to LAB color space

This conversion allows for more perceptually accurate color representation and better matches human color perception.

### Multi-Screenshot Consistency

To ensure stability across different screenshots:

1. Apply color extraction to each screenshot individually
2. Weight results based on:
   - Quality score of the screenshot
   - Confidence in segmentation results
   - Lighting conditions
3. Calculate final LAB values as weighted average across screenshots

## Accuracy Assessment

Based on our research, the accuracy of this approach is expected to be high due to:

1. **Performance Optimization**:
   - Separating real-time tracking from intensive image segmentation improves performance
   - Allows for more thorough processing of segmentation on selected high-quality frames
   - Strategic screenshot selection ensures only the best frames are used for critical color analysis

2. **MediaPipe's Segmentation Accuracy**:
   - The multi-class selfie segmentation model has demonstrated high precision in identifying hair and skin regions
   - Segmentation works well across different skin tones and hair colors

3. **Face Landmark Precision**:
   - 478 landmarks provide highly detailed facial mapping
   - Landmarks maintain stability across frames even with movement

4. **Combined Approach Benefits**:
   - Using landmarks for real-time tracking improves user experience
   - Processing multiple screenshots allows cross-validation between different captures
   - Enables more precise region targeting without performance penalties

5. **Lighting Correction Effectiveness**:
   - Multiple screenshots at different head positions provide varied lighting samples
   - Comparison across these positions improves lighting normalization

## Integration with colorAnalysisApp

### Swift Implementation

Since colorAnalysisApp uses Swift 6.1, the implementation will require:

1. **MediaPipe Integration**:
   - Use MediaPipe's iOS SDK
   - Implement through Swift wrappers around MediaPipe's C++ core

2. **Processing Pipeline**:
   - Implement as a two-phase process: real-time tracking and post-capture analysis
   - Use Swift's concurrency features for background processing of screenshots
   - Provide user feedback during the capture phase

3. **Memory Management**:
   - Implement efficient screenshot storage using compressed formats
   - Use Swift's ARC (Automatic Reference Counting) to manage resources

### API Design

The proposed API for integration with colorAnalysisApp:

```swift
// Main processor class
class VideoColorProcessor {
    // Initialize with configuration
    init(config: ProcessorConfig)
    
    // Process real-time video frame and return preliminary skin analysis
    func processFrame(frame: CVPixelBuffer) -> FrameQualityResult
    
    // Capture strategic screenshot when quality threshold is met
    func captureScreenshot(frame: CVPixelBuffer) -> Bool
    
    // Process captured screenshots (call after video session)
    func processScreenshots() async -> ColorResults
    
    // Reset state (e.g., when starting a new session)
    func reset()
}

// Frame quality assessment
struct FrameQualityResult {
    let qualityScore: Float
    let preliminarySkinRGB: RGB?
    let facePosition: FacePosition
    let isGoodForCapture: Bool
}

// Results structure
struct ColorResults {
    let skinColorLAB: LABColor
    let hairColorLAB: LABColor
    let eyeColorLAB: LABColor?
    let confidence: Float
}

// LAB Color representation
struct LABColor {
    let l: Float // Lightness
    let a: Float // Green-Red component
    let b: Float // Blue-Yellow component
}
```

## Limitations and Mitigations

### Potential Limitations

1. **Processing Flow**:
   - Two-phase approach requires clear user guidance during video capture
   - **Mitigation**: Implement intuitive UI with real-time feedback on face positioning and screenshot capture

2. **Screenshot Storage**:
   - Multiple high-quality screenshots could use significant memory
   - **Mitigation**: Use compressed formats and discard screenshots after processing

3. **Extreme Lighting Conditions**:
   - Very dark or very bright environments may still reduce accuracy
   - **Mitigation**: Implement detection of poor lighting conditions and provide feedback to users

4. **Unusual Hair Colors**:
   - Non-natural hair colors may affect segmentation accuracy
   - **Mitigation**: Implement additional validation checks for unusual color values

5. **Occlusions**:
   - Glasses, masks, or other face coverings may affect results
   - **Mitigation**: Detect occlusions and adjust sampling regions or provide guidance to users

## Conclusion

The revised video processing workflow leverages MediaPipe's face landmark detection for real-time tracking and strategic screenshot capture, with image segmentation performed separately afterward. This separation optimizes performance while maintaining high accuracy for extracting LAB color values.

This approach offers several advantages over traditional methods:

1. **Performance**: Separating compute-intensive processes improves real-time responsiveness
2. **Precision**: Strategic screenshot capture ensures high-quality inputs for color analysis
3. **Robustness**: Multiple screenshots at different angles improve lighting correction
4. **Efficiency**: Resources are focused on processing only the highest quality frames
5. **User Experience**: Real-time landmark tracking provides immediate feedback while maintaining app responsiveness

The implementation will require integration with colorAnalysisApp's Swift codebase, but the benefits in terms of accuracy, reliability, and performance make this approach highly recommended for the project's needs.
