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
- **ImageSegmenter/Views/DefaultSeasonView.swift** - Displays standard information for each season type
- **ImageSegmenter/Views/PersonalizedSeasonView.swift** - Displays AI-generated personalized recommendations and styling advice

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
- **ImageSegmenter/Services/SeasonClassifier.swift** - Classifies user into a seasonal color category (supports 12 detailed seasons)
- **ImageSegmenter/Services/ClassificationService.swift** - Manages the overall classification process including contrast calculation and personalization orchestration
- **ImageSegmenter/Services/PersonalizationService.swift** - Integrates with OpenAI API to generate personalized color recommendations
- **ImageSegmenter/Services/CoreDataManager.swift** - Handles data persistence using Core Data including contrast data
- **ImageSegmenter/Services/ToastService.swift** - Displays toast notifications to users

### Metal Shaders

- **ImageSegmenter/Services/Shaders.metal** - General Metal shaders for image processing
- **ImageSegmenter/Services/DownsamplingShader.metal** - Metal shader for image downsampling
- **ImageSegmenter/Services/ColorConversionShader.metal** - Metal shader for color space conversions

### Models

- **ImageSegmenter/Models/AnalysisResult.swift** - Data model for color analysis results including contrast properties and detailed season names
- **ImageSegmenter/Models/PersonalizedSeasonData.swift** - Data model for personalized AI-generated season recommendations
- **ImageSegmenter/Models/Season.swift** - Season model supporting 12 detailed season classifications
- **ImageSegmenter/Models/SeasonAnalysis.xcdatamodeld/** - Core Data model for persisting analysis results with contrast data
- **ImageSegmenter/Models/APIKeyFileManager.swift** - Manages secure API key configuration for external services

### ViewModels

- **ImageSegmenter/ViewModels/AnalysisViewModel.swift** - Main view model for analysis workflow
- **ImageSegmenter/ViewModels/CameraViewModel.swift** - View model managing camera operations and analysis pipeline with frame processing optimization
- **ImageSegmenter/ViewModels/SeasonViewModel.swift** - View model for season-specific content and data loading

### Utilities

- **ImageSegmenter/Utils/ColorConverters.swift** - Utilities for color space conversion (RGB, Lab, HSV)
- **ImageSegmenter/Utils/ContrastCalculator.swift** - Calculates contrast levels between facial features using Delta-E color difference
- **ImageSegmenter/Utils/ConnectedComponentAnalysis.swift** - Processes connected components in segmentation
- **ImageSegmenter/Utils/FaceLandmarkQualityCalculator.swift** - Evaluates quality of detected facial landmarks
- **ImageSegmenter/Utils/BufferPoolManager.swift** - Manages pools of reusable buffers
- **ImageSegmenter/Utils/TexturePoolManager.swift** - Manages pools of reusable Metal textures
- **ImageSegmenter/Utils/PixelBufferPoolManager.swift** - Manages pools of reusable pixel buffers
- **ImageSegmenter/Utils/NotificationManager.swift** - Coordinates timing between analysis completion and personalization with 30-second timeout handling
- **ImageSegmenter/Utils/SeasonViewNavigationManager.swift** - Manages navigation between default and personalized season views
- **ImageSegmenter/Utils/AppConfiguration.swift** - Centralized app configuration including personalization feature toggles

### Extensions

- **ImageSegmenter/Extensions/CoreData+PersonalizationData.swift** - Core Data extensions for PersonalizedSeasonData persistence (currently stubbed for future implementation)

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
6. **SeasonClassifier** analyzes segmented regions to determine detailed seasonal color category (12-season system)
7. **ClassificationService** orchestrates analysis and triggers personalization workflow
8. **PersonalizationService** generates AI-powered personalized recommendations via OpenAI API
9. **CoreDataManager** persists analysis results including contrast data

### Personalized Season Workflow

1. **ClassificationService** completes analysis and stops frame processing for optimization
2. **NotificationManager** receives analysis result and starts 30-second personalization timeout
3. **PersonalizationService** sends user data to OpenAI API for personalized recommendations
4. **PersonalizationService** parses response and creates **PersonalizedSeasonData** object
5. **NotificationManager** receives personalization completion and cancels timeout
6. **SeasonViewNavigationManager** determines whether to show **PersonalizedSeasonView** or **DefaultSeasonView**
7. **SeasonViewModel** loads appropriate season data based on detailed season name
8. Fallback to **DefaultSeasonView** if personalization fails or times out

### UI Flow

1. **RootViewController** initializes the application and manages navigation between landing page and camera
2. **LandingPageView** provides season exploration and entry point to analysis
3. **RefactoredCameraViewController** handles camera preview and analysis triggering
4. **Metal rendering** pipeline (**PreviewMetalView**, **Shaders**, **Renderers**) displays real-time feedback
5. **CameraViewModel** coordinates the analysis pipeline and manages state with frame processing optimization
6. **AnalysisResultViewModel** processes results for display
7. **NotificationManager** coordinates timing between analysis and personalization
8. **SeasonViewNavigationManager** routes to appropriate results view:
   - **PersonalizedSeasonView** for AI-generated personalized recommendations (when API available)
   - **DefaultSeasonView** for standard season information (fallback)
9. **SavedResultsView** displays previously stored results

### Contrast Analysis Pipeline

1. **ColorConverters** converts UI colors to Lab color space for accurate color comparison
2. **ContrastCalculator** computes Delta-E color differences between skin, hair, and eye colors
3. **ContrastAnalysisResult** provides structured contrast data including level classification and descriptions
4. **AnalysisResultView** displays contrast information with a 5-bar visual indicator
5. **CoreDataManager** persists contrast values for historical analysis

### Personalized Season Analysis Pipeline

1. **APIKeyFileManager** securely loads OpenAI API key from `ApiKeys.plist`
2. **AppConfiguration** determines if personalization is active based on API key availability
3. **SeasonClassifier** provides both `macroSeason` (UI compatibility) and `detailedSeason` (12-season specificity)
4. **ClassificationService** creates **AnalysisResult** with `detailedSeasonName` and triggers personalization
5. **PersonalizationService** constructs prompt with user's color data and detailed season information
6. **PersonalizationService** sends HTTP request to OpenAI API using gpt-4o-mini model
7. **PersonalizationService** parses JSON response extracting:
   - `personalizedTagline` - Custom tagline for the user
   - `userCharacteristics` - Analysis of user's unique coloring
   - `personalizedOverview` - Tailored season description
   - `colorRecommendations` - Specific color suggestions
   - `colorsToAvoid` - Colors to avoid
   - `emphasizedColors` - Key colors to emphasize
   - `stylingAdvice` - Practical styling tips
   - `confidence` - AI confidence in recommendations
8. **PersonalizedSeasonData** model encapsulates all AI-generated content
9. **NotificationManager** handles timing with 30-second timeout and cancellation logic
10. **SeasonViewModel** loads season JSON files from bundle root using detailed season names
11. **PersonalizedSeasonView** displays AI content with season-appropriate theming

## Key Technologies

Per the **techstack.md** document, the application uses:

- **Swift** and **SwiftUI** (with UIKit integration) for the frontend
- **Metal** for high-performance GPU rendering
- **MediaPipe** framework for facial landmark detection and image segmentation
- **Core Data** for local data persistence including contrast analysis data
- **Combine Framework with MVVM Pattern** for state management
- **CIEDE2000** Delta-E algorithm for perceptually accurate color difference calculations
- **OpenAI API** integration for personalized AI-generated season recommendations
- **URLSession** for secure HTTP communication with external APIs
- **12-Season Color Analysis System** supporting detailed seasonal classifications

## Build and Run

The application is built using Xcode 16.3 and CocoaPods for dependency management. The minimum iOS version supported is iOS 13.0.

### Configuration Files

- **ApiKeys.plist** - Secure storage for API keys (should be placed in project root)
  - Contains `openai_api_key` for OpenAI API integration
  - File should be added to Xcode project bundle for runtime access
  - Must be excluded from version control for security

### API Integration Setup

1. Create `ApiKeys.plist` in project root with OpenAI API key
2. Add file to Xcode project bundle (drag into project navigator)
3. Ensure file is included in target membership
4. PersonalizationService will automatically detect and use API key
5. App gracefully falls back to DefaultSeasonView if no API key is configured

## Recent Updates

### Personalized Season Analysis Workflow (Latest)
- **OpenAI API Integration**: Added PersonalizationService with gpt-4o-mini model integration for personalized color recommendations
- **12-Season Detailed Classification**: Enhanced SeasonClassifier to support detailed seasons (e.g., "True Summer", "Soft Autumn") alongside macro seasons
- **Advanced Timing Management**: Implemented NotificationManager with 30-second timeout handling and cancellation logic for seamless user experience
- **Frame Processing Optimization**: CameraViewModel now stops frame processing during API calls to conserve resources and improve performance
- **Dual View System**: Created PersonalizedSeasonView for AI content and enhanced DefaultSeasonView for fallback scenarios
- **Secure API Configuration**: Added APIKeyFileManager with bundle-based API key loading via ApiKeys.plist
- **Enhanced Core Data Models**: Extended AnalysisResult to include detailedSeasonName for precise season tracking
- **Navigation Management**: Implemented SeasonViewNavigationManager for intelligent routing between personalized and default views
- **Error Handling & Fallbacks**: Comprehensive error handling with graceful fallbacks when personalization fails or times out

### Technical Improvements (Latest)
- **Resource Management**: Added frame processing controls (stopFrameProcessing, resumeFrameProcessing) for better performance
- **API Response Parsing**: Robust JSON parsing for OpenAI responses with comprehensive error handling
- **Season Data Loading**: Enhanced SeasonViewModel with fallback logic for loading season JSON files from bundle root
- **Notification System**: Advanced notification coordination between analysis completion and personalization results
- **Debug Logging**: Extensive logging throughout personalization pipeline for debugging and monitoring

### Contrast Analysis Feature (Previous)
- Added comprehensive contrast calculation using Lab color space and Delta-E 2000 algorithm
- Integrated contrast visualization with 5-level indicator system
- Extended Core Data model to persist contrast analysis results
- Enhanced UI to display contrast levels with human-readable descriptions

### Development Rules & Guidelines (Previous)
- Added Cursor rules for automatic project documentation updates
- Implemented comprehensive Swift best practices enforcement
- Created development workflow standards for code quality and consistency

### Architecture Improvements (Previous)
- Refactored camera controller with improved delegate pattern
- Enhanced view model architecture for better state management
- Improved error handling and user feedback systems

## Future Considerations

### Core Data Enhancements
- **PersonalizationResult Entity**: Currently PersonalizedSeasonData Core Data persistence is stubbed out pending addition of PersonalizationResult entity to the Core Data model
- **Cross-Session Personalization**: Future Core Data integration will enable saving and retrieving personalized recommendations across app sessions

### API Integration Expansion
- **Rate Limiting**: Consider implementing client-side rate limiting for OpenAI API calls
- **Caching**: Add intelligent caching of personalized results to reduce API costs
- **Multiple AI Providers**: Architecture supports future integration with additional AI services

### Backend Infrastructure (Optional)
The application architecture includes potential for a backend component using Python with FastAPI, though this is currently optional with the direct OpenAI integration. If implemented, it would provide:
- Cross-device syncing of personalized recommendations
- User profiles and preference learning
- Analytics and usage insights
- Centralized API key management
- Rate limiting and cost optimization
