# Project Directory

This document outlines the structure of the colorAnalysisApp project, detailing key files, their dependencies, and usage relationships to facilitate easier navigation and understanding.

## Project Overview

The colorAnalysisApp is an iOS mobile application built with Swift that provides color analysis for users based on the 12 seasonal color analysis system. The app captures facial images, analyzes skin and hair colors, and provides personalized styling recommendations based on the user's assigned season.

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
- **ImageSegmenter/ViewContoller/MediaLibraryViewController.swift** - Manages photo library access and image selection
- **ImageSegmenter/ViewContoller/BottomSheetViewController.swift** - Displays information in a bottom sheet UI
- **ImageSegmenter/ViewContoller/AnalysisResultViewModel.swift** - View model for displaying analysis results

### Views

- **ImageSegmenter/Views/PreviewMetalView.swift** - Metal-powered view for real-time camera preview
- **ImageSegmenter/Views/DebugOverlayView.swift** - Overlay for displaying debug information during development
- **ImageSegmenter/Views/AnalysisResultView.swift** - Displays user's color analysis results
- **ImageSegmenter/Views/FrameQualityIndicatorView.swift** - Visual indicator for frame capture quality
- **ImageSegmenter/Views/SavedResultsView.swift** - Shows previously saved analysis results

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
- **ImageSegmenter/Services/ClassificationService.swift** - Manages the overall classification process
- **ImageSegmenter/Services/CoreDataManager.swift** - Handles data persistence using Core Data
- **ImageSegmenter/Services/ToastService.swift** - Displays toast notifications to users

### Metal Shaders

- **ImageSegmenter/Services/Shaders.metal** - General Metal shaders for image processing
- **ImageSegmenter/Services/DownsamplingShader.metal** - Metal shader for image downsampling
- **ImageSegmenter/Services/ColorConversionShader.metal** - Metal shader for color space conversions

### Models

- **ImageSegmenter/Models/AnalysisResult.swift** - Data model for color analysis results
- **ImageSegmenter/Models/SeasonAnalysis.xcdatamodeld/** - Core Data model for persisting analysis results

### Utilities

- **ImageSegmenter/Utils/ColorConverters.swift** - Utilities for color space conversion
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

## Dependency Relationships

### Core Processing Pipeline

1. **CameraFeedService** captures video frames
2. **FaceLandmarkerService** detects facial landmarks in frames
3. **ImageSegmenterService** segments facial features (skin, hair, eyes)
4. **FrameQualityService** evaluates frame quality using **FaceLandmarkQualityCalculator**
5. **SeasonClassifier** analyzes segmented regions to determine seasonal color category
6. **CoreDataManager** persists analysis results

### UI Flow

1. **RootViewController** initializes and coordinates between different views
2. **CameraViewController** handles camera preview and analysis triggering
3. **Metal rendering** pipeline (**PreviewMetalView**, **Shaders**, **Renderers**) displays real-time feedback
4. **AnalysisResultViewModel** processes results for display
5. **AnalysisResultView** shows seasonal classification and recommendations
6. **SavedResultsView** displays previously stored results

## Key Technologies

Per the **techstack.md** document, the application uses:

- **Swift** and **SwiftUI** (with UIKit integration) for the frontend
- **Metal** for high-performance GPU rendering
- **MediaPipe** framework for facial landmark detection and image segmentation
- **Core Data** for local data persistence
- **Combine Framework with MVVM Pattern** for state management

## Build and Run

The application is built using Xcode and CocoaPods for dependency management. The minimum iOS version supported is iOS 13.0.

## Future Considerations

The application architecture includes potential for a backend component using Python with FastAPI, though this is currently optional. If implemented, it would provide cross-device syncing, user profiles, and remote data storage through a RESTful API. 