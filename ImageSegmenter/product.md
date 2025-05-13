# Color Analysis App Technical Documentation

## Overview
Our application utilizes the MediaPipe image segmentation capabilities to provide advanced visual processing features. This document outlines the current implementation and feature development.

## Development Environment
- Xcode 16.3
- Swift 6.1

## Rules

### Swift Coding Standards
All Swift code in this project must adhere to the following standards:

1. **Follow Apple's Swift API Design Guidelines**:
   * Use clear, expressive naming that prioritizes clarity at the point of use
   * Follow proper case conventions (UpperCamelCase for types/protocols, lowerCamelCase for everything else)
   * Use value-preserving type conversion naming patterns
   * Name methods with side effects using verb phrases (e.g., `sort()`)
   * Name methods without side effects using noun phrases (e.g., `distance(to:)`)

2. **Code Formatting**:
   * Use consistent indentation (4 spaces recommended, not tabs)
   * Place only one statement per line
   * Keep lines to a reasonable length (120 characters maximum)
   * Use proper spacing around operators, after commas, and between control flow statements and parentheses

3. **Documentation Comments**:
   * Use Swift-flavored Markdown syntax for documentation (`/** */` for multi-line, `///` for single-line)
   * Every public property, method, class, and function should include documentation comments
   * Include a summary line at the beginning followed by a detailed description if needed
   * Use parameter, returns, and throws documentation sections as appropriate:
     ```swift
     /**
      * Processes image segmentation based on the selected model.
      *
      * - Parameters:
      *   - inputImage: The source image to process
      *   - model: The segmentation model to apply
      * - Returns: A processed image with segments highlighted
      * - Throws: `SegmentationError.invalidInput` if the image format is incompatible
      */
     ```
   * Use callouts for additional information (e.g., `- Note:`, `- Important:`, `- Attention:`)
   * Document code complexity where relevant with `- Complexity: O(n)`

4. **Best Practices**:
   * Favor `let` over `var` when the value won't change
   * Use Swift types instead of Objective-C legacy types where possible
   * Make computed properties O(1) or document their complexity
   * Group related constants using enums as namespaces
   * Respect access control principles to hide implementation details

### Rule for Adding New Files to the Project
When creating new files for the project, follow these steps to ensure they're properly included in Xcode:
1. **Create the file in the appropriate directory** in the project structure
1. **Add the file to the Xcode project**:
   * Open the Xcode project file (project.pbxproj) in a text editor
   * Add an entry in the PBXFileReference section with appropriate file type
   * Add a corresponding entry in the PBXBuildFile section
   * Add the file to the appropriate PBXGroup section
   * For source files (.swift, .metal), add the file to the PBXSourcesBuildPhase section
   * For resource files (.md, .tflite, etc.), add the file to the PBXResourcesBuildPhase section

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

## Recent Bug Fixes

### Texture Copy Size Mismatch Fix (June 2024)

#### Issue Description
When switching to the MultiClass segmentation model, users encountered a critical render failure with the following error:
```
-[MTLDebugBlitCommandEncoder internalValidateCopyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:options:]:496: failed assertion `Copy From Texture Validation
(destinationOrigin.x + destinationSize.width)(1080) must be <= width(270).
(destinationOrigin.y + destinationSize.height)(1920) must be <= height(480).
```

The error occurred because the application was attempting to copy texture data from a large source texture (1080×1920) to a smaller destination texture (270×480) without properly handling the size difference.

#### Solution Implemented
The issue was resolved by implementing a CPU-based downsampling approach that properly handles the texture size mismatch:

1. **Replaced problematic blit operations:** The direct Metal blit encoder copy operation was replaced with a safer CPU-based downsampling method.

2. **Added proper dimension verification:** The code now correctly checks and handles size differences between source and destination textures.

3. **Created a knowledge base document:** A new `knowledge.md` file was created to document this issue and other Metal texture handling best practices for future reference.

This fix ensures that the MultiClass segmentation model can now be used without crashing, allowing users to access the facial feature analysis functionality.

For technical details about this fix and similar Metal texture handling issues, refer to the `knowledge.md` file in the project repository.

## Technical Requirements
- iOS 13.0 or later
- Swift 5.0+
- MediaPipe framework integration
- Camera and processing permissions

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
