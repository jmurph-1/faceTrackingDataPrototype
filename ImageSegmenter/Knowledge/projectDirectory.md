# Project Directory

This document outlines the structure of the colorAnalysisApp project, detailing key files, their dependencies, and usage relationships to facilitate easier navigation and understanding.

## Project Overview

The colorAnalysisApp is an iOS mobile application built with Swift that provides color analysis for users based on the 12 seasonal color analysis system. The app captures facial images, analyzes skin and hair colors, calculates contrast between facial features, and provides personalized styling recommendations based on the user's assigned season and contrast level.

## Directory Structure

### Root Level

- **ImageSegmenter/** - Main application code
- **ImageSegmenter.xcodeproj/** - Xcode project files
- **ImageSegmenter.xcworkspace/** - Xcode workspace files (integrates with CocoaPods)
- **ImageSegmenterTests/** - Test cases for the application
- **Pods/** - Dependencies managed by CocoaPods
- **RunScripts/** - Build and automation scripts
- **Podfile** - CocoaPods dependency definition file
- **Podfile.lock** - Locked versions of dependencies
- **README.md** - Project overview and documentation
- **LICENSE** - Project license information

## Core Application Components

### Entry Points

- **ImageSegmenter/AppDelegate.swift** - Application entry point handling application lifecycle events
- **ImageSegmenter/SceneDelegate.swift** - Manages scene-based application lifecycle events for newer iOS versions

### Machine Learning Models

- **ImageSegmenter/face_landmarker.task** - MediaPipe face landmark detection model
- **ImageSegmenter/selfie_multiclass_256x256.tflite** - TensorFlow Lite model for facial feature segmentation

### View Controllers

- **ImageSegmenter/ViewContoller/RootViewController.swift** - Main container controller for the application
- **ImageSegmenter/ViewContoller/CameraViewController.swift** - Handles camera capture and processing 
- **ImageSegmenter/ViewContoller/RefactoredCameraViewController.swift** - Updated version of the camera controller with improved architecture
- **ImageSegmenter/ViewContoller/AnalysisResultViewModel.swift** - View model for displaying analysis results

### Views

- **ImageSegmenter/Views/PreviewMetalView.swift** - Metal-powered view for real-time camera preview
- **ImageSegmenter/Views/DebugOverlayView.swift** - Overlay for displaying debug information during development
- **ImageSegmenter/Views/AnalysisResultView.swift** - Displays user's color analysis results including contrast analysis
- **ImageSegmenter/Views/FrameQualityIndicatorView.swift** - Visual indicator for frame capture quality
- **ImageSegmenter/Views/SavedResultsView.swift** - Shows previously saved analysis results
- **ImageSegmenter/Views/LandingPageView.swift** - Main landing page with season exploration
- **ImageSegmenter/Views/DefaultSeasonView.swift** - Displays information for each season type

### Services

- **ImageSegmenter/Services/CameraService.swift** - Manages camera configuration and capture session
- **ImageSegmenter/Services/CameraFeedService.swift** - Handles camera feed processing
- **ImageSegmenter/Services/FaceLandmarkerService.swift** - Integrates with MediaPipe for facial landmark detection
- **ImageSegmenter/Services/ImageSegmenterService.swift** - Integrates with MediaPipe for image segmentation
- **ImageSegmenter/Services/SegmentationService.swift** - Coordinates the image segmentation process
- **ImageSegmenter/Services/SegmentedImageRenderer.swift** - Renders segmented images using Metal
- **ImageSegmenter/Services/MultiClassSegmentedImageRenderer.swift** - Renders multi-class segmentation results
- **ImageSegmenter/Services/FaceLandmarkRenderer.swift** - Renders facial landmarks on images
- **ImageSegmenter/Services/FrameQualityService.swift** - Analyzes frame quality for optimal analysis
- **ImageSegmenter/Services/FrameQualityAnalyzer.swift** - Computes metrics for frame quality
- **ImageSegmenter/Services/SeasonClassifier.swift** - Classifies user into a seasonal color category
- **ImageSegmenter/Services/ClassificationService.swift** - Manages the overall classification process including contrast calculation
- **ImageSegmenter/Services/CoreDataManager.swift** - Handles data persistence using Core Data including contrast data
- **ImageSegmenter/Services/ToastService.swift** - Displays toast notifications to users

### Metal Shaders

- **ImageSegmenter/Services/Shaders.metal** - General Metal shaders for image processing
- **ImageSegmenter/Services/DownsamplingShader.metal** - Metal shader for image downsampling
- **ImageSegmenter/Services/ColorConversionShader.metal** - Metal shader for color space conversions

### Models

- **ImageSegmenter/Models/AnalysisResult.swift** - Data model for color analysis results including contrast properties
- **ImageSegmenter/Models/SeasonAnalysis.xcdatamodeld/** - Core Data model for persisting analysis results with contrast data

### ViewModels

- **ImageSegmenter/ViewModels/AnalysisViewModel.swift** - Main view model for analysis workflow
- **ImageSegmenter/ViewModels/CameraViewModel.swift** - View model managing camera operations and analysis pipeline

### Utilities

- **ImageSegmenter/Utils/ColorConverters.swift** - Utilities for color space conversion (RGB, Lab, HSV)
- **ImageSegmenter/Utils/ContrastCalculator.swift** - Calculates contrast levels between facial features using Delta-E color difference
- **ImageSegmenter/Utils/ConnectedComponentAnalysis.swift** - Processes connected components in segmentation
- **ImageSegmenter/Utils/FaceLandmarkQualityCalculator.swift** - Evaluates quality of detected facial landmarks
- **ImageSegmenter/Utils/BufferPoolManager.swift** - Manages pools of reusable buffers
- **ImageSegmenter/Utils/TexturePoolManager.swift** - Manages pools of reusable Metal textures
- **ImageSegmenter/Utils/PixelBufferPoolManager.swift** - Manages pools of reusable pixel buffers

### Documentation

- **ImageSegmenter/Knowledge/techstack.md** - Documents the technology stack used in the application
- **ImageSegmenter/Knowledge/requirements.md** - Detailed requirements specification
- **ImageSegmenter/Knowledge/prd.md** - Product requirements document
- **ImageSegmenter/Knowledge/frontend.md** - Frontend architecture and implementation details
- **ImageSegmenter/Knowledge/backend.md** - Backend architecture and implementation details
- **ImageSegmenter/Knowledge/flow.md** - Application flow and user journey documentation
- **ImageSegmenter/Knowledge/status.md** - Current project status and progress tracking
- **ImageSegmenter/Knowledge/PerformanceOptimizationPlan.md** - Plan for optimizing application performance
- **ImageSegmenter/Knowledge/video_processing_plan.md** - Plan for video processing functionality
- **ImageSegmenter/Knowledge/Phase0.3_Implementation_Checklist.md** - Implementation checklist for Phase 0.3
- **ImageSegmenter/Knowledge/projectDirectory.md** - This document, providing a map of the project

### Development Rules & Guidelines

- **.cursor/rules/critical-kb.mdc** - Rule to use techstack.md as ground truth for technology questions
- **.cursor/rules/project-documentation.mdc** - Rule ensuring projectDirectory.md stays updated with changes
- **.cursor/rules/swift-best-practices.mdc** - Comprehensive Swift coding standards and best practices enforcement

## Dependency Relationships

### Core Processing Pipeline

1. **CameraFeedService** captures video frames
2. **FaceLandmarkerService** detects facial landmarks in frames
3. **ImageSegmenterService** segments facial features (skin, hair, eyes)
4. **FrameQualityService** evaluates frame quality using **FaceLandmarkQualityCalculator**
5. **ContrastCalculator** analyzes contrast between facial features using Lab color space and Delta-E calculations
6. **SeasonClassifier** analyzes segmented regions to determine seasonal color category
7. **CoreDataManager** persists analysis results including contrast data

### UI Flow

1. **RootViewController** initializes the application and manages navigation between landing page and camera
2. **LandingPageView** provides season exploration and entry point to analysis
3. **RefactoredCameraViewController** handles camera preview and analysis triggering
4. **Metal rendering** pipeline (**PreviewMetalView**, **Shaders**, **Renderers**) displays real-time feedback
5. **CameraViewModel** coordinates the analysis pipeline and manages state
6. **AnalysisResultViewModel** processes results for display
7. **AnalysisResultView** shows seasonal classification, contrast analysis, and recommendations with visual indicators
8. **SavedResultsView** displays previously stored results

### Contrast Analysis Pipeline

1. **ColorConverters** converts UI colors to Lab color space for accurate color comparison
2. **ContrastCalculator** computes Delta-E color differences between skin, hair, and eye colors
3. **ContrastAnalysisResult** provides structured contrast data including level classification and descriptions
4. **AnalysisResultView** displays contrast information with a 5-bar visual indicator
5. **CoreDataManager** persists contrast values for historical analysis

## Key Technologies

Per the **techstack.md** document, the application uses:

- **Swift** and **SwiftUI** (with UIKit integration) for the frontend
- **Metal** for high-performance GPU rendering
- **MediaPipe** framework for facial landmark detection and image segmentation
- **Core Data** for local data persistence including contrast analysis data
- **Combine Framework with MVVM Pattern** for state management
- **CIEDE2000** Delta-E algorithm for perceptually accurate color difference calculations

## Build and Run

The application is built using Xcode 16.3 and CocoaPods for dependency management. The minimum iOS version supported is iOS 13.0.

## Recent Updates

### Contrast Analysis Feature (Latest)
- Added comprehensive contrast calculation using Lab color space and Delta-E 2000 algorithm
- Integrated contrast visualization with 5-level indicator system
- Extended Core Data model to persist contrast analysis results
- Enhanced UI to display contrast levels with human-readable descriptions

### Development Rules & Guidelines (Latest)
- Added Cursor rules for automatic project documentation updates
- Implemented comprehensive Swift best practices enforcement
- Created development workflow standards for code quality and consistency

### Architecture Improvements
- Refactored camera controller with improved delegate pattern
- Enhanced view model architecture for better state management
- Improved error handling and user feedback systems

## Future Considerations

The application architecture includes potential for a backend component using Python with FastAPI, though this is currently optional. If implemented, it would provide cross-device syncing, user profiles, and remote data storage through a RESTful API. 
