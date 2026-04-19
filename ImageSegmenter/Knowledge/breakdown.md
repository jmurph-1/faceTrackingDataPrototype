 ---
  Complete System Reverse-Engineering Report: Season13 iOS Color Analysis Application

  1. Executive Summary

  What the application is:
  Season13 is a native iOS application (minimum iOS 14.0) that performs professional seasonal color analysis using computer
  vision, color science, and AI-powered personalization.

  Problem it solves:
  The app determines a user's optimal color palette from 12 seasonal categories (Light/True/Bright Spring, Light/True/Soft
  Summer, Soft/True/Dark Autumn, Dark/True/Bright Winter) based on facial features, skin undertones, hair color, and eye color.
  It provides personalized styling recommendations using OpenAI's GPT-4o-mini with "Season DNA" analysis that identifies
  primary/secondary/tertiary seasonal influences.

  Major capabilities:
  - Real-time face detection and color extraction using MediaPipe (478-point face landmarker, multi-class segmentation)
  - Perceptually accurate color analysis using Lab color space and CIEDE2000 Delta-E calculations
  - GPU-accelerated rendering via Metal shaders
  - White balance calibration system for accurate color measurement
  - AI-powered personalized recommendations with fallback to local color database
  - Frame quality evaluation with real-time feedback
  - Local persistence via Core Data
  - 12-season classification with confidence scoring and DNA-blend analysis

  Overall architectural style:
  MVVM (Model-View-ViewModel) with Combine framework for reactive programming, delegate pattern for service communication, and
  protocol-oriented design for testability. The architecture is modular with clear separation between UI (SwiftUI/UIKit),
  business logic (Services), state management (ViewModels), and data (Models/Core Data).

  ---
  2. System Purpose and Product Behavior

  What the user can do:

  1. Browse Default Season Information (LandingPageView.swift:1-150)
    - View 12 season categories organized by 4 macro-seasons
    - Tap abbreviated season buttons (e.g., "brt", "tru", "drk") to view default season information
    - Access comprehensive season details including palette, styling, and characteristics
  2. Perform Live Color Analysis (RefactoredCameraViewController.swift:16-1122)
    - Grant camera permissions
    - Position face in calibration frame
    - Capture white reference for color calibration (or skip)
    - Monitor real-time frame quality indicators (face size, position, brightness, sharpness)
    - Trigger analysis when quality thresholds are met
    - View analysis results with assigned season and personalized recommendations
  3. View Personalized Results (PersonalizedSeasonView.swift:1-300)
    - Access Season DNA visualization showing primary/secondary/tertiary influences
    - Browse enhanced color recommendations from AI or local database
    - Explore best neutrals, accents, and base colors with usage context
    - View colors to avoid
    - Access full palette explorer with favorites
  4. Review Saved Analyses (SavedResultsView.swift:mentioned)
    - Browse historical analysis results stored in Core Data
    - Re-view past season assignments with thumbnails

  Main user journeys:

  Journey 1: First-Time Analysis
  Launch App → LandingPageView → Tap Camera Button → Camera Permission Request →
  Grant Permission → Calibration Mode (Capture White Reference or Skip) →
  Analysis Mode → Position Face → Real-time Quality Feedback →
  Tap "Analyze" → Processing (MediaPipe + Color Extraction + Classification) →
  OpenAI Personalization (or Fallback) → PersonalizedSeasonView Display →
  Save Result to Core Data

  Journey 2: Browse Seasons
  Launch App → LandingPageView → Tap Season Abbreviation → DefaultSeasonView →
  View Season Details (Palette, Characteristics, Styling)

  Journey 3: Review Past Results
  Launch App → Navigate to SavedResultsView → Select Saved Result →
  View Personalized or Default Season Page

  Core business workflows:

  1. White Balance Calibration Workflow (CameraViewModel.swift:155-339)
    - App enters calibration mode on launch
    - User positions white reference card in center box (10% of frame)
    - Captures 5 frames at center region
    - Calculates RGB average and white balance factors
    - Applies calibration to ColorExtractor for accurate color measurement
    - Stores calibration as WhiteBalanceCalibration struct
  2. Frame Processing Pipeline (CameraViewModel.swift:181-219)
    - Camera captures CMSampleBuffer at ~30 FPS
    - ViewModel receives frame via CameraServiceDelegate.didOutput
    - Frame is throttled to process every 100ms
    - MediaPipe FaceLandmarker detects 478 facial landmarks
    - MediaPipe ImageSegmenter performs multi-class segmentation (skin, hair, eyes, lips, eyebrows)
    - ColorExtractor processes segmentation mask + texture to extract colors
    - FrameQualityService evaluates frame suitability (weighted: 25% face size, 25% position, 30% brightness, 20% sharpness)
    - Results propagated to UI via delegate callbacks
  3. Analysis Workflow (ClassificationService.swift:44-120, CameraViewModel.swift:143-153)
    - User triggers analysis when frame quality ≥ 0.7
    - ClassificationService receives pixel buffer + ColorInfo
    - Converts colors to Lab space
    - SeasonClassifier performs 12-season classification using lightness/chroma/hue ranges
    - Calculates confidence via dimensionScore algorithm
    - Creates AnalysisResult with detailed season name
    - Notifies delegate (triggers PersonalizationService)
  4. Personalization Workflow (PersonalizationService.swift:172-223, ClassificationService.swift:124-159)
    - ClassificationService loads Season.json data for detailed season
    - Calls PersonalizationService.generateDNAPersonalization
    - Creates DNA-enhanced prompt with user's Lab color values
    - Sends request to OpenAI API (gpt-4o-mini, 45s timeout, 2 retry attempts)
    - Parses JSON response into PersonalizedSeasonData with SeasonDNA
    - On failure/timeout: creates enhanced fallback using ColorDatabaseManager
    - Posts notification to trigger UI update
    - Frame processing remains stopped until user dismisses results

  Important app states and transitions:

  States tracked in CameraViewModel.swift:44-47, 73-82:
  - CameraMode: .calibration | .analysis
  - isSessionRunning: Camera session active/inactive
  - isCalibrated: White balance calibration complete
  - isDetectingWhiteReference: Actively capturing white reference frames
  - shouldProcessFrames: Frame processing enabled/disabled
  - isAnalyzeButtonPressed: Debounce state for analyze button

  State Machine:
  App Launch → Calibration Mode (shouldProcessFrames=false) →
  User Captures White Reference → Calibration Complete → Analysis Mode (shouldProcessFrames=true) →
  User Triggers Analysis → Frame Processing Stops → API Call → Results Display →
  User Dismisses → Return to Analysis Mode (shouldProcessFrames=true if shouldAutoStartAnalysis)

  Inputs, outputs, and side effects:

  Inputs:
  - Camera CMSampleBuffer stream (AVFoundation)
  - User touch events (analyze button, navigation)
  - White reference calibration card
  - OpenAI API responses (JSON)
  - Local JSON files (seasons/*.json, colors.json, thresholds.json)
  - ApiKeys.plist (OPENAI_API_KEY)

  Outputs:
  - Metal-rendered camera preview with overlays (PreviewMetalView.swift)
  - Analysis results displayed in UI
  - Core Data persistence (AnalysisResult entities)
  - Toast notifications for errors/warnings
  - Console logging via LoggingService

  Side Effects:
  - Core Data writes to local database
  - Memory allocation from object pools (BufferPoolManager, TexturePoolManager, PixelBufferPoolManager)
  - GPU texture creation and rendering
  - Network requests to OpenAI API
  - NotificationCenter postings for cross-component communication

  ---
  3. Architecture Overview

  High-level architecture:
  The app follows a layered MVVM architecture with service-oriented business logic:

  ┌─────────────────────────────────────────────────────┐
  │         Presentation Layer (SwiftUI + UIKit)        │
  │  LandingPageView │ PersonalizedSeasonView │        │
  │  DefaultSeasonView │ RefactoredCameraViewController│
  └──────────────────────┬──────────────────────────────┘
                         │
  ┌──────────────────────▼──────────────────────────────┐
  │           ViewModel Layer (State Management)        │
  │  CameraViewModel │ PersonalizedSeasonViewModel     │
  │  AnalysisResultViewModel                            │
  └──────────────────────┬──────────────────────────────┘
                         │
  ┌──────────────────────▼──────────────────────────────┐
  │              Service Layer (Business Logic)         │
  │  CameraService │ FaceLandmarkerService │           │
  │  SegmentationService │ ClassificationService │      │
  │  PersonalizationService │ FrameQualityService │     │
  │  ColorExtractor │ SeasonClassifier │                │
  │  ColorDatabaseManager │ CoreDataManager             │
  └──────────────────────┬──────────────────────────────┘
                         │
  ┌──────────────────────▼──────────────────────────────┐
  │             Model Layer (Data Structures)           │
  │  AnalysisResult │ PersonalizedSeasonData │         │
  │  Season │ SeasonDNA │ ColorItem │ MetalRecommendation│
  └─────────────────────────────────────────────────────┘
                         │
  ┌──────────────────────▼──────────────────────────────┐
  │            Infrastructure Layer (Frameworks)        │
  │  MediaPipe │ Metal │ Core Data │ AVFoundation │    │
  │  Combine │ URLSession                               │
  └─────────────────────────────────────────────────────┘

  Main layers/components:

  1. Presentation Layer
    - SwiftUI Views: Declarative UI components
    - UIKit ViewControllers: Camera capture and Metal rendering
    - UIHostingController: Bridges SwiftUI views into UIKit hierarchy
  2. ViewModel Layer
    - State containers using @Published properties
    - Combine publishers for reactive updates
    - Delegate pattern to communicate with services
  3. Service Layer
    - Stateless business logic processors
    - Protocol-oriented interfaces for testability
    - Modular extensions (e.g., PersonalizationService+DNAHelpers, PersonalizationService+Parsing)
  4. Model Layer
    - Immutable data structures (structs)
    - NSSecureCoding-compliant classes for persistence
    - Codable conformance for JSON serialization

  Frontend/backend/mobile/shared modules:

  Frontend (iOS App):
  - Views: 13 SwiftUI views, 5 UIKit ViewControllers
  - ViewModels: 5 state management classes
  - Services: 28 service files
  - Models: 7 core model files
  - Utils: 20 utility files
  - Extensions: 2 extension files

  Backend (External):
  - OpenAI API (GPT-4o-mini) for personalization
  - No custom backend server (all processing on-device)

  Shared Resources:
  - MediaPipe models: face_landmarker.task (3.8 MB), selfie_multiclass_256x256.tflite (16.3 MB)
  - JSON data: 12 season files, colors.json (80 KB), thresholds.json
  - Metal shaders: Shaders.metal, DownsamplingShader.metal, ColorConversionShader.metal

  How components communicate:

  1. Delegate Pattern (CameraViewModelDelegate.swift:22-42)
    - ViewControllers conform to ViewModel delegates
    - Async callbacks for frame updates, quality scores, errors
    - Example: CameraViewModel → RefactoredCameraViewController via didUpdateFrameQuality
  2. Combine Publishers (implicit in ViewModels)
    - @Published properties trigger UI updates automatically
    - SwiftUI views observe @StateObject ViewModels
  3. NotificationCenter (NotificationManager.swift)
    - Cross-module communication for analysis results
    - Notifications: "AnalysisResultReady", "PersonalizationReady", "PersonalizationFailed"
    - 30-second timeout mechanism for API calls
  4. Protocol Conformance
    - Services implement protocols (e.g., SegmentationServiceDelegate, PersonalizationServiceDelegate)
    - Enables loose coupling and dependency injection
  5. Direct Method Calls
    - ViewModels call service methods synchronously
    - Services return results via completion handlers or delegates

  Key patterns used:

  1. MVVM (Model-View-ViewModel)
    - Views: Presentation logic only
    - ViewModels: State management and coordination
    - Models: Data structures
    - Services: Business logic
  2. Delegate Pattern
    - Async communication between layers
    - Protocols define contracts (e.g., CameraViewModelDelegate, ClassificationServiceDelegate)
  3. Service-Oriented Architecture
    - Each service has single responsibility
    - Services are stateless or maintain minimal state
    - Modular extensions for large services
  4. Observer Pattern (via Combine)
    - @Published properties notify observers
    - Reactive UI updates
  5. Factory Pattern
    - MockPersonalizedSeasonDataFactory for test data
    - SeasonTheme.getTheme(for:) for theme creation
  6. Strategy Pattern
    - Different color extraction algorithms (high accuracy vs fast)
    - White balance calibration strategies
  7. Object Pooling
    - BufferPoolManager, TexturePoolManager, PixelBufferPoolManager
    - Reduces allocation overhead for real-time processing

  ---
  4. Entry Points and Runtime Flow

  Startup sequence (AppDelegate.swift:6-29, SceneDelegate.swift:8-14):

  1. @main AppDelegate.application(_:didFinishLaunchingWithOptions:)
     - Configure console logging (disable OS_ACTIVITY filtering)
     - Enable unbuffered stderr
     - Log app start via DebugLogger
     - Return true

  2. AppDelegate.application(_:configurationForConnecting:options:)
     - Return UISceneConfiguration("Default Configuration")

  3. SceneDelegate.scene(_:willConnectTo:options:)
     - Relies on Main.storyboard for initial UI
     - No programmatic window/root VC setup

  4. Storyboard instantiation (Main.storyboard → Info.plist:19-20)
     - Loads RootViewController as initial view controller
     - RootViewController.viewDidLoad() triggers app initialization

  Main entry points:

  1. App Launch Entry (RootViewController.swift:39-53)
  RootViewController.viewDidLoad()
  - setupRefactoredCameraViewController() // Instantiates camera VC from storyboard
  - setupLandingPageViewController() // Creates SwiftUI landing page
  - Initially shows landing page, camera view hidden
  2. Camera Analysis Entry (RootViewController.swift:149-164)
  RootViewController.showCameraView()
  - Sets shouldAutoStartAnalysis = true
  - Unhides RefactoredCameraViewController
  - Calls prepareAndStartCameraIfNeeded()
  - Camera starts, enters calibration mode
  3. Season Exploration Entry (LandingPageView.swift:141-147)
  onSubSeasonTapped: { seasonName in
      showDefaultSeasonView(for: seasonName)
  }
  - Creates DefaultSeasonView with season theme
  - Presents modally fullscreen

  Initialization logic:

  CameraViewModel Initialization (CameraViewModel.swift:84-96):
  init() {
      cameraService.delegate = self
      segmentationService.delegate = self
      classificationService.delegate = self
      configureInitialServices()
  }

  configureInitialServices() {
      configureSegmentationService() // Load selfie_multiclass_256x256.tflite
      configureFaceLandmarkerService() // Load face_landmarker.task
  }

  Service Configuration (CameraViewModel.swift:366-387):
  configureSegmentationService():
  - Get model path from InferenceConfigurationManager
  - Call segmentationService.configure(with: modelPath)

  configureFaceLandmarkerService():
  - Load "face_landmarker.task" from bundle
  - Create FaceLandmarkerService.liveStreamFaceLandmarkerService
  - Set as liveStreamDelegate

  Routing/navigation flow:

  Navigation Hierarchy:
  UIWindow (SceneDelegate)
  └── RootViewController (UIViewController)
      ├── RefactoredCameraViewController (UIKit, hidden initially)
      │   └── PreviewMetalView (UIViewRepresentable → Metal rendering)
      └── LandingPageViewController (UIHostingController<LandingPageView>)
          └── LandingPageView (SwiftUI)
              ├── Season Module Buttons → DefaultSeasonView (modal)
              └── Camera Button → showCameraView()

  Navigation Methods (RootViewController.swift:119-179):
  - showDefaultSeasonView(for:): Present season info modally
  - showCameraView(): Transition to camera with cross-dissolve animation
  - showLandingPage(): Return to landing page, stop camera

  Request lifecycle:

  Not applicable - this is a local processing app with no traditional request/response cycle. The closest equivalent is the
  Analysis Request Lifecycle:

  User taps "Analyze" →
  RefactoredCameraViewController.analyzeButtonTapped() →
  Check frame quality (guard currentQuality.isAcceptableForAnalysis) →
  Show loading spinner →
  CameraViewModel.analyzeCurrentFrame() →
  ClassificationService.analyzeFrame(pixelBuffer:colorInfo:) →
  SeasonClassifier.classifySeason(skinLab:hairLab:) →
  Create AnalysisResult →
  ClassificationService.attemptPersonalization(for:detailedSeason:) →
  PersonalizationService.generateDNAPersonalization(...) →
  Make OpenAI API request (45s timeout) →
  Parse JSON response →
  Create PersonalizedSeasonData →
  Post "PersonalizationReady" notification →
  RefactoredCameraViewController.handlePersonalizationReady(_:) →
  presentPersonalizationResultView(result:) →
  Remove loading spinner

  Background jobs, async flows, event handlers, scheduled tasks, listeners:

  Async Frame Processing (CameraViewModel.swift:481-492):
  CameraServiceDelegate.didOutput(sampleBuffer:orientation:) {
      backgroundQueue.async { [weak self] in
          self?.processFrame(sampleBuffer:orientation:timeStamps:)
      }
  }
  - Runs on dedicated DispatchQueue("com.google.mediapipe.cameraViewModel.backgroundQueue")
  - Processes frames asynchronously to avoid blocking main thread

  Async Landmark Detection (CameraViewModel.swift:216, 418):
  faceLandmarkerService?.detectLandmarksAsync(
      sampleBuffer: sampleBuffer,
      orientation: orientation,
      timeStamps: Int(currentTime * 1000)
  )
  - MediaPipe processes on internal threads
  - Results delivered via FaceLandmarkerServiceLiveStreamDelegate.faceLandmarkerService(_:didFinishLandmarkDetection:error:)

  Scene Lifecycle Handlers (SceneDelegate.swift:16-61):
  sceneDidDisconnect(_:)
  - Post UIApplication.didReceiveMemoryWarningNotification
  - Clear all object pools (TexturePoolManager, BufferPoolManager, PixelBufferPoolManager)

  sceneWillResignActive(_:)
  - Post memory warning notification preemptively

  sceneDidEnterBackground(_:)
  - Clear all object pools again

  App Lifecycle Handlers (RefactoredCameraViewController.swift:362-393):
  handleAppWillEnterForeground() {
      viewModel.stopCamera()
      if shouldAutoStartAnalysis && view.window != nil {
          viewModel.startCamera()
      }
  }
  - Registered via NotificationCenter for UIApplication.willEnterForegroundNotification

  Scheduled Tasks:
  - FPS calculation: Every 1 second (CameraViewModel.swift:210-214)
  - Frame throttling: Process frames max every 100ms (CameraViewModel.swift:203-206)

  Event Listeners:
  - NotificationCenter observers for analysis results (RefactoredCameraViewController.swift:372-392)
  - UITapGestureRecognizer for debug overlay (3-finger tap)
  - Button touch handlers throughout views

  ---
  5. Module-by-Module Breakdown

  Module: Camera & Video Processing

  Files:
  - CameraService.swift
  - CameraFeedService.swift
  - CameraViewModel.swift
  - RefactoredCameraViewController.swift
  - PreviewMetalView.swift

  Responsibility:
  Capture live video stream, manage AVFoundation session, provide CMSampleBuffer frames to processing pipeline, render processed
  frames with Metal.

  Key classes/functions:
  - CameraService: Manages AVCaptureSession, AVCaptureDevice configuration, handles permissions
  - CameraViewModel.processFrame(sampleBuffer:orientation:timeStamps:): Entry point for frame processing
  - CameraViewModel.startCamera(): Initialize and start camera session
  - PreviewMetalView: UIView subclass with CAMetalLayer for GPU rendering

  Dependencies:
  - AVFoundation for camera capture
  - Metal/MetalKit for rendering
  - MediaPipe for face detection
  - SegmentationService for processing

  Data consumed:
  - Camera permission status
  - Device camera capabilities
  - User's face positioning

  Data produced:
  - CVPixelBuffer stream at ~30 FPS
  - Camera session state (running/stopped/interrupted)
  - Processed frames with segmentation overlays

  Interactions:
  - Delegates to CameraViewModel via CameraServiceDelegate
  - CameraViewModel delegates to RefactoredCameraViewController
  - PreviewMetalView receives pixelBuffers directly from ViewModel

  Edge cases:
  - Camera permission denied: Show alert, guide to Settings
  - No rear camera (simulator): Use front camera
  - Session interruption (phone call): Resume when interruption ends
  - Background mode: Stop session to save resources

  Module: Face Detection & Segmentation

  Files:
  - FaceLandmarkerService.swift
  - ImageSegmenterService.swift
  - SegmentationService.swift
  - MultiClassSegmentedImageRenderer.swift
  - FaceLandmarkRenderer.swift

  Responsibility:
  Detect 478 facial landmarks, perform multi-class segmentation (skin, hair, eyes, lips, eyebrows), render segmentation masks for
   visualization.

  Key classes/functions:
  - FaceLandmarkerService.liveStreamFaceLandmarkerService(modelPath:liveStreamDelegate:): Factory method for live stream mode
  - ImageSegmenterService.segment(mpImage:orientation:): Performs segmentation inference
  - SegmentationService.processFrame(sampleBuffer:orientation:timeStamps:): Coordinates segmentation workflow
  - SegmentationService.textureCache: CVMetalTextureCache for efficient texture creation

  Dependencies:
  - MediaPipeTasksVision framework (0.10.14)
  - Metal for texture processing
  - ColorExtractor for color analysis

  Data consumed:
  - CMSampleBuffer from camera
  - Face landmark coordinates from MediaPipe
  - Model files: face_landmarker.task, selfie_multiclass_256x256.tflite

  Data produced:
  - 478 NormalizedLandmark points (x, y, z coordinates)
  - Segmentation mask (UInt8 array, class IDs per pixel)
  - Face bounding box (CGRect)
  - SegmentationResult struct with outputPixelBuffer

  Interactions:
  - Receives frames from CameraViewModel
  - Provides landmarks to ColorExtractor for region-of-interest selection
  - Delegates segmentation results to CameraViewModel

  Edge cases:
  - No face detected: Returns nil landmarks, empty segmentation
  - Multiple faces: Processes only first face
  - Poor lighting: May produce noisy segmentation masks
  - Extreme angles: Landmark detection may fail

  Module: Color Extraction & Analysis

  Files:
  - ColorExtractor.swift
  - accurate_color_extraction.swift
  - ColorExtractor+Constrants.swift
  - ColorExtractor+Utils.swift
  - ColorConverters.swift
  - ContrastCalculator.swift

  Responsibility:
  Extract representative colors from segmented facial regions, convert between color spaces (RGB ↔ Lab ↔ HSV), calculate
  contrast using CIEDE2000, apply white balance correction.

  Key classes/functions:
  - ColorExtractor.extractColorsOptimized(from:segmentMask:width:height:): Main extraction entry point
  - ColorExtractor.extractColorsHighAccuracy(...): Uses landmark-guided region analysis
  - ColorExtractor.applyWhiteBalance(to:): Applies calibration factors to RGB values
  - ColorConverters.colorToLab(_:): RGB → Lab conversion (D65 illuminant)
  - ContrastCalculator.analyzeContrast(skinColor:hairColor:eyeColor:): CIEDE2000-based contrast

  Dependencies:
  - Metal for texture access
  - MediaPipe landmarks for region selection
  - White balance calibration data

  Data consumed:
  - MTLTexture (camera frame)
  - Segmentation mask (UInt8 pointer)
  - Face landmarks (cheek, forehead, iris indices)
  - WhiteBalanceCalibration factors

  Data produced:
  - ColorInfo struct:
    - skinColor, hairColor, leftEyeColor, rightEyeColor, averageEyeColor (UIColor)
    - HSV tuples for each color
    - Eye confidence scores (0.0-1.0)
  - Lab color values (L, a, b)
  - Contrast analysis (value, level, description)

  Interactions:
  - Receives textures from SegmentationService
  - Consumes landmarks from FaceLandmarkerService
  - Provides ColorInfo to ClassificationService
  - Used by FrameQualityService for brightness calculation

  Edge cases:
  - Insufficient skin pixels: Falls back to broader region
  - Iris not detected: Uses eye region average
  - Extreme lighting: White balance correction may overcorrect
  - Hair covering forehead: Forehead region excluded from skin calculation

  Module: Season Classification

  Files:
  - SeasonClassifier.swift
  - ClassificationService.swift

  Responsibility:
  Classify user into one of 12 detailed seasons based on Lab color values, lightness, chroma, and hue. Calculate confidence
  scores and delta-E to alternative seasons.

  Key classes/functions:
  - SeasonClassifier.classify(skinColor:hairColor:): Main classification algorithm
  - SeasonClassifier.classifySeasonWithConfidence(lightness:chroma:hue:): Rule-based matcher
  - SeasonClassifier.dimensionScore(value:rangeMin:rangeMax:): Fuzzy matching score
  - SeasonClassifier.calculateDeltaEToSeasonReferences(labColor:): Color distance to season prototypes
  - ClassificationService.analyzeFrame(pixelBuffer:colorInfo:): Orchestrates full analysis

  Dependencies:
  - ColorExtractor for input colors
  - ColorConverters for Lab conversion
  - ContrastCalculator for contrast analysis
  - PersonalizationService for AI recommendations

  Data consumed:
  - Skin Lab color (L, a, b)
  - Hair Lab color (optional)
  - Eye Lab colors (optional)
  - Thresholds from thresholds.json

  Data produced:
  - ClassificationResult:
    - detailedSeason: DetailedSeason enum (e.g., .trueSummer)
    - macroSeason: Season enum (.spring, .summer, .autumn, .winter)
    - confidence: Float 0-1 from dimensionScore
    - deltaEToNextClosest: Color distance to second-best match
    - nextClosestSeason: Alternative season suggestion
  - AnalysisResult (comprehensive result object)

  Interactions:
  - Called by ClassificationService after color extraction
  - Provides results to PersonalizationService
  - Stores results via CoreDataManager

  Edge cases:
  - Ambiguous coloring (low confidence): Still assigns best match, shows lower confidence
  - Out-of-range Lab values: Clamped to valid ranges
  - Missing hair/eye data: Classification still proceeds with skin data only
  - Thresholds file missing: Uses hardcoded defaults

  Assumptions:
  - Skin Lab color is most reliable indicator
  - 12-season ranges cover all human coloring variations
  - CIEDE2000 provides perceptually accurate color matching
  - Reference season colors are scientifically validated

  Module: AI Personalization

  Files:
  - PersonalizationService.swift
  - PersonalizationService+DNAHelpers.swift
  - PersonalizationService+Parsing.swift
  - PersonalizationService+ResponsesAPI.swift
  - ColorDatabaseManager.swift

  Responsibility:
  Generate AI-powered personalized color recommendations using OpenAI GPT-4o-mini, analyze Season DNA (primary/secondary/tertiary
   influences), provide fallback recommendations via local color database.

  Key classes/functions:
  - PersonalizationService.generateDNAPersonalization(for:seasonData:detailedSeasonName:completion:): Main personalization entry
  - PersonalizationService.createDNAPersonalizationPrompt(...): Builds GPT-4o-mini prompt
  - PersonalizationService.makeOpenAIRequestWithRetry(...): HTTP request with retry logic
  - PersonalizationService+DNAHelpers.createFallbackSeasonDNA(...): Generate DNA from analysis
  - PersonalizationService+Parsing.parseDNAJSONToPersonalizedData(...): Parse API response
  - ColorDatabaseManager.findMatchingColors(...): Database lookup for fallback

  Dependencies:
  - URLSession for API communication
  - JSONSerialization for parsing
  - APIKeyManager for secure key access
  - Season.json files for season context
  - colors.json for database fallback

  Data consumed:
  - AnalysisResult (Lab colors, season, confidence)
  - Season struct (characteristics, palette, styling)
  - ApiKeys.plist (OPENAI_API_KEY)
  - Network availability

  Data produced:
  - PersonalizedSeasonData:
    - personalizedTagline, userCharacteristics, personalizedOverview
    - seasonDNAData: SeasonDNA with primary/secondary/tertiary weights
    - enhancedColorData: EnhancedColorRecommendations with ColorItems
    - colorRecommendations: PersonalizedColorRecommendations
    - emphasizedColors, colorsToAvoid: [String] hex colors
    - metals: [MetalRecommendation] for jewelry
    - confidence: Float 0-1
  - Notifications: "PersonalizationReady" or "PersonalizationFailed"

  Interactions:
  - Called by ClassificationService after season determination
  - Posts NotificationCenter events to CameraViewModel
  - Falls back to ColorDatabaseManager on API failure
  - Stores PersonalizedSeasonData in Core Data (via extension)

  Edge cases:
  - API key missing: Immediate fallback to database
  - Network unavailable: Database fallback
  - API timeout (45s): Retry once, then fallback
  - Invalid JSON response: Fallback with error logging
  - Partial JSON (truncated): Fallback gracefully
  - API rate limit: Shows error, uses fallback

  Assumptions:
  - GPT-4o-mini understands 12-season color theory
  - JSON structure matches schema exactly
  - DNA analysis improves recommendation quality
  - ColorDatabase has sufficient coverage for all seasons

  Module: Frame Quality Assessment

  Files:
  - FrameQualityService.swift
  - FrameQualityEvaluator.swift
  - FrameQualityAnalyzer.swift

  Responsibility:
  Evaluate video frame suitability for analysis based on face size, position, brightness, and sharpness. Provide real-time
  feedback to guide user positioning.

  Key classes/functions:
  - FrameQualityService.evaluateFrameQualityWithLandmarks(pixelBuffer:landmarks:imageSize:): Landmark-based evaluation
  - FrameQualityEvaluator.faceSizeScore(landmarks:imageSize:): 0-1 score for face area
  - FrameQualityEvaluator.facePositionScore(landmarks:imageSize:): Centering score
  - FrameQualityEvaluator.brightnessScore(landmarks:pixelBuffer:): Lighting adequacy
  - FrameQualityEvaluator.sharpnessScore(landmarks:pixelBuffer:): Blur detection via Laplacian variance

  Dependencies:
  - MediaPipe landmarks for face metrics
  - CVPixelBuffer for brightness/sharpness analysis
  - Core Image filters for Laplacian calculation

  Data consumed:
  - CVPixelBuffer (camera frame)
  - [NormalizedLandmark] (478 points)
  - Image size (CGSize)

  Data produced:
  - QualityScore struct:
    - overall: Weighted average (25% size + 25% position + 30% brightness + 20% sharpness)
    - faceSize: 0-1 score
    - facePosition: 0-1 score
    - brightness: 0-1 score
    - sharpness: 0-1 score
    - isAcceptableForAnalysis: Bool (overall ≥ 0.7 && all individual metrics meet thresholds)
    - feedbackMessage: Optional String with improvement guidance

  Interactions:
  - Called by CameraViewModel for every processed frame
  - Results delegated to RefactoredCameraViewController
  - Powers FrameQualityIndicatorView UI component
  - Gates analysis trigger (analyzeButton.isEnabled)

  Edge cases:
  - Face too close: faceSizeScore > 1.0 (acceptable)
  - Face too far: faceSizeScore < 0.6 (reject, show "Move closer")
  - Off-center: facePositionScore < 0.7 (reject, show "Center your face")
  - Dim lighting: brightnessScore < 0.6 (reject, show "Find better lighting")
  - Motion blur: sharpnessScore < 0.5 (show "Hold still")

  Early Termination Optimization:
  Evaluates metrics sequentially, returns early if score < threshold * 0.7 to avoid expensive calculations.

  Module: UI/Presentation

  Views (SwiftUI):
  - LandingPageView.swift: Home screen with season exploration
  - PersonalizedSeasonView.swift: AI-personalized results with DNA visualization
  - DefaultSeasonView.swift: Static season information
  - AnalysisResultView.swift: Basic analysis results with contrast
  - FrameQualityIndicatorView.swift: Real-time quality feedback
  - SeasonDNARingChart.swift: Visual DNA blend representation
  - EnhancedColorGrid.swift: Color palette display with tooltips
  - SeasonPaletteExplorerView.swift: Full palette browser with favorites
  - PersonalizedMetalsGrid.swift: Jewelry recommendations
  - MetallicColorDisplay.swift: Metallic finish visualization
  - DebugOverlayView.swift: Developer overlay with Lab values and FPS
  - SavedResultsView.swift: Historical results browser

  ViewControllers (UIKit):
  - RootViewController.swift: Root navigation container
  - RefactoredCameraViewController.swift: Camera capture and analysis UI
  - AnalysisResultViewModel.swift: Result presentation logic

  Responsibility:
  Present UI, handle user interactions, display analysis results, navigate between screens, provide visual feedback.

  Key functions:
  - LandingPageView.seasonModuleView(mainSeason:): Renders season buttons
  - PersonalizedSeasonView.enhancedColorPalette: Displays AI-recommended colors
  - RefactoredCameraViewController.analyzeButtonTapped(): Triggers analysis
  - RefactoredCameraViewController.presentAnalysisResultView(result:): Shows results modal

  Dependencies:
  - ViewModels for state
  - SeasonTheme for styling
  - NotificationCenter for cross-screen events

  Data consumed:
  - AnalysisResult from ViewModel
  - PersonalizedSeasonData from ViewModel
  - Season structs from bundle JSON
  - SeasonTheme configurations

  Data produced:
  - User tap events
  - Navigation triggers
  - State changes via @State/@Published

  Interactions:
  - Observes ViewModels via Combine
  - Calls ViewModel methods on user actions
  - Presents/dismisses child views

  Edge cases:
  - No personalization data: Shows DefaultSeasonView instead
  - Missing season JSON: Shows mock season
  - Long color lists: Scrollable grids
  - Small screens: Adaptive layout

  Module: Data Persistence

  Files:
  - CoreDataManager.swift
  - AnalysisResult.swift
  - AnalysisResult+Personalization.swift
  - CoreData+PersonalizationData.swift

  Responsibility:
  Store and retrieve analysis results, manage Core Data stack, handle data migration.

  Key classes/functions:
  - CoreDataManager.saveAnalysisResult(_:): Persist AnalysisResult to Core Data
  - CoreDataManager.fetchAllAnalysisResults(): Retrieve saved results
  - AnalysisResult.save(to:): Convert to NSManagedObject
  - AnalysisResult.init(from:): Create from NSManagedObject

  Dependencies:
  - Core Data framework
  - NSSecureCoding for AnalysisResult
  - JSONEncoder/Decoder for PersonalizedSeasonData

  Data consumed:
  - AnalysisResult instances
  - PersonalizedSeasonData instances
  - Core Data model schema

  Data produced:
  - Persisted analysis results
  - Historical data for SavedResultsView

  Interactions:
  - Called by ClassificationService after analysis
  - Queried by SavedResultsView on launch
  - Automatic background saves

  Edge cases:
  - Storage full: Show error, prevent save
  - Corrupted data: Skip corrupted records, log error
  - Migration needed: Automatic schema migration
  - Concurrent access: Core Data handles via NSManagedObjectContext

  ---
  6. Data Model and State Management

  Core domain entities:

  1. AnalysisResult (AnalysisResult.swift:6-414)
  class AnalysisResult: NSObject, NSSecureCoding {
      let season: SeasonClassifier.Season // Macro season
      let detailedSeasonName: String // e.g., "True Summer"
      let confidence: Float
      let deltaEToNextClosest: Float
      let nextClosestSeason: SeasonClassifier.Season

      let skinColor: UIColor
      let skinColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?
      let hairColor: UIColor?
      let hairColorLab: (L: CGFloat, a: CGFloat, b: CGFloat)?
      let leftEyeColor, rightEyeColor, averageEyeColor: UIColor?
      let leftEyeColorLab, rightEyeColorLab, averageEyeColorLab: (L, a, b)?
      let leftEyeConfidence, rightEyeConfidence: Float

      let contrastValue: Double
      let contrastLevel: String // "Low", "Medium-Low", "Medium", "Medium-High", "High"
      let contrastDescription: String

      let date: Date
      let thumbnail: UIImage?
      var notes: String?
  }
  2. PersonalizedSeasonData (PersonalizedSeasonData.swift:148-248)
  struct PersonalizedSeasonData: Codable {
      let id: UUID
      let createdDate: Date
      let baseSeason: String
      let personalizedTagline: String
      let userCharacteristics: String
      let personalizedOverview: String
      let colorRecommendations: PersonalizedColorRecommendations
      let emphasizedColors: [String] // Hex values
      let colorsToAvoid: [String]
      let confidence: Float
      let analysisResultId: UUID?

      // Enhanced DNA support
      let seasonDNAData: SeasonDNA?
      let enhancedColorData: EnhancedColorRecommendations?
      let metals: [MetalRecommendation]?
  }
  3. SeasonDNA (PersonalizedSeasonData.swift:31-80)
  struct SeasonDNA: Codable {
      let primary: SeasonWeight // Weight 0.6-0.85
      let secondary: SeasonWeight? // Weight 0.15-0.35
      let tertiary: SeasonWeight? // Weight 0.05-0.15
      let explanation: String
      let classificationConfidence: Float
      let blendJustification: String?

      var isPureMatch: Bool { primary.weight > 0.85 }
      var blendDescription: String // e.g., "True Summer with Light Summer influence"
  }
  4. Season (Season.swift:7-150)
  struct Season: Identifiable, Decodable {
      let name: String
      let tagline: String
      let introduction: String
      let characteristics: Characteristics
      let palette: Palette
      let styling: Styling

      struct Characteristics {
          let note, overview: String
          let features: Features // eyes, skin, hair, contrast
      }

      struct Palette {
          let description: String
          let hue, value, chroma: ColorAspect
          let sisterPalettes: SisterPalettes
      }

      struct Styling {
          let neutrals: StyleDescription
          let colorsToAvoid: ColorsToAvoid
          let colorCombinations, patternsAndPrints: ...
          let metalsAndAccessories: ...
      }
  }
  5. ColorItem (PersonalizedSeasonData.swift:85-116)
  struct ColorItem: Codable, Identifiable {
      let id: UUID
      let name: String
      let hexValue: String
      let usageContext: String // "Perfect for blouses and scarves"
      let harmonyReason: String // "Complements your cool undertone"
      var isRecommended: Bool
  }
  6. MetalRecommendation (MetalRecommendation.swift)
  struct MetalRecommendation {
      let type: String // "Gold", "Silver", "Rose Gold"
      let finish: String // "Polished", "Matte", "Brushed"
      let description: String
      let priority: String // "High", "Medium", "Low"
  }

  Data schemas/models/types:

  Enums:
  - SeasonClassifier.Season: .spring, .summer, .autumn, .winter
  - SeasonClassifier.DetailedSeason: 12 cases (.lightSpring, .trueSummer, etc.)
  - CameraMode: .calibration, .analysis
  - CameraError, AnalysisError, PersonalizationError

  Value Types (Structs):
  - Most models are structs for value semantics and Codable support
  - ColorInfo, QualityScore, ClassificationResult, SeasonDNA

  Reference Types (Classes):
  - AnalysisResult (NSSecureCoding for Core Data)
  - ViewModels (ObservableObject for state management)
  - Services (stateful singletons or per-instance)

  State containers/stores/view models:

  1. CameraViewModel (CameraViewModel.swift:50-82)
  class CameraViewModel: NSObject {
      @Published private(set) var isSessionRunning = false
      @Published private(set) var currentFrameQualityScore: QualityScore?
      @Published private(set) var currentColorInfo: ColorInfo?
      @Published private(set) var lastFaceLandmarks: [NormalizedLandmark]?
      @Published private(set) var currentFPS: Float = 0.0

      private let cameraService = CameraService()
      private let segmentationService = SegmentationService()
      private let classificationService = ClassificationService()
      private var faceLandmarkerService: FaceLandmarkerService?

      private(set) var currentMode: CameraMode = .calibration
      private(set) var whiteBalanceCalibration: WhiteBalanceCalibration?
      private(set) var isCalibrated: Bool = false
  }
  2. PersonalizedSeasonViewModel (PersonalizedSeasonViewModel.swift)
  class PersonalizedSeasonViewModel: ObservableObject {
      @Published var personalizedData: PersonalizedSeasonData
      @Published var seasonName: String

      var seasonDNA: SeasonDNA {
          personalizedData.seasonDNA // With fallback creation
      }

      func getFullPaletteColors() -> [ColorItem]
      func getDNAConfidenceColor() -> Color
  }

  How state changes over time:

  Calibration Flow State Progression:
  currentMode = .calibration
  isDetectingWhiteReference = false
  shouldProcessFrames = false
  ↓ (User taps "Capture White Reference")
  isDetectingWhiteReference = true
  ↓ (5 frames captured)
  whiteBalanceCalibration = WhiteBalanceCalibration(...)
  isCalibrated = true
  currentMode = .analysis
  isDetectingWhiteReference = false
  shouldProcessFrames = true

  Analysis Flow State Progression:
  currentFrameQualityScore?.isAcceptableForAnalysis = false
  analyzeButton.isEnabled = false
  ↓ (User positions face correctly)
  currentFrameQualityScore.overall = 0.85
  analyzeButton.isEnabled = true
  ↓ (User taps Analyze)
  shouldProcessFrames = false
  ↓ (Analysis complete)
  NotificationCenter posts "AnalysisResultReady"
  ↓ (Results displayed)
  shouldProcessFrames remains false until dismiss

  Persistence mechanisms:

  Core Data Stack (inferred from usage):
  NSPersistentContainer
  └── NSManagedObjectContext (main queue)
      └── AnalysisResultEntity
          ├── season: String
          ├── detailedSeasonName: String
          ├── confidence: Float
          ├── skinColorData: Data (archived UIColor)
          ├── skinColorLabL, skinColorLabA, skinColorLabB: Double
          ├── contrastValue: Double
          ├── thumbnailData: Data (PNG)
          └── ... (all AnalysisResult properties)

  Save Operations:
  CoreDataManager.saveAnalysisResult(analysisResult) {
      let entity = NSEntityDescription.insertNewObject(forEntityName: "AnalysisResult", into: context)
      analysisResult.save(to: entity)
      try context.save()
  }

  Caching behavior:

  1. Object Pools (memory caching):
    - BufferPoolManager: Reuses CVPixelBuffers (max 10 buffers)
    - TexturePoolManager: Recycles MTLTextures (max 10 textures)
    - PixelBufferPoolManager: Maintains CVPixelBufferPools for different sizes
  2. Texture Cache:
    - CVMetalTextureCache in SegmentationService
    - Automatically managed by Core Video
    - Flushes on memory warnings
  3. No HTTP caching (API calls are stateless, no response caching)
  4. No image caching (frames processed in real-time, not stored)

  Session/auth/user context handling:

  No traditional authentication system.

  Session Management:
  - Camera session: AVCaptureSession lifecycle managed by CameraService
  - Analysis session: Single-shot, no persistent session
  - App session: State reset on backgrounding/foregrounding

  User Context:
  - No user accounts or profiles
  - All data stored locally on device
  - No cross-device synchronization
  - Privacy: All processing on-device, no data sent to servers except OpenAI API (Lab colors + season name only)

  API Authentication:
  - OpenAI API key stored in ApiKeys.plist (git-ignored)
  - Bearer token authentication: Authorization: Bearer sk-...
  - No refresh tokens or session management

  ---
  7. API and Integration Surface

  Internal APIs:

  The app has no traditional HTTP API. Internal communication is via:

  1. Delegate Protocols (Service → ViewModel → ViewController):
  protocol CameraViewModelDelegate: AnyObject {
      func viewModel(_:, didUpdateFrameQuality:)
      func viewModel(_:, didUpdateSegmentedBuffer:)
      func viewModel(_:, didUpdateColorInfo:)
      func viewModel(_:, didEncounterError:)
      func viewModelDidStartCamera(_:)
      func viewModelDidStopCamera(_:)
      ...
  }
  2. Service Methods (Synchronous/Async):
  // CameraService
  func startLiveCameraSession(completion: (CameraConfiguration) -> Void)
  func stopSession()

  // ClassificationService
  func analyzeFrame(pixelBuffer: CVPixelBuffer, colorInfo: ColorExtractor.ColorInfo)

  // PersonalizationService
  func generateDNAPersonalization(for:seasonData:detailedSeasonName:completion:)

  External APIs/services:

  OpenAI Chat Completions API (PersonalizationService.swift:25, 489-598):

  Endpoint: https://api.openai.com/v1/chat/completions

  Authentication: Bearer token in Authorization header

  Request:
  {
    "model": "gpt-4o",
    "messages": [
      {
        "role": "system",
        "content": "You are an expert color analyst specializing in Season DNA analysis using the 12-season color system..."
      },
      {
        "role": "user",
        "content": "USER'S MEASURED COLORS:\n- Season Classification: True Summer\n- Skin Color (Lab): L: 72.5, a: 8.3, b: 
  15.2\n..."
      }
    ],
    "max_tokens": 5000,
    "temperature": 0.7,
    "response_format": { "type": "json_object" }
  }

  Response:
  {
    "choices": [
      {
        "message": {
          "content":
  "{\"personalizedTagline\":\"...\",\"userCharacteristics\":\"...\",\"seasonDNA\":{\"primary\":{\"season\":\"True 
  Summer\",\"weight\":0.75},...},\"enhancedColorData\":{...}}"
        }
      }
    ]
  }

  Timeout: 45 seconds
  Retry Logic: 2 attempts with 2-second delay
  Error Handling: Fallback to ColorDatabaseManager on failure

  Database interactions:

  Core Data Entities (inferred):

  Entity: AnalysisResult
  - Attributes: season, detailedSeasonName, confidence, deltaE, skinColorData, hairColorData, skinColorLabL/A/B,
  hairColorLabL/A/B, leftEyeColorData, rightEyeColorData, averageEyeColorData, leftEyeConfidence, rightEyeConfidence,
  contrastValue, contrastLevel, contrastDescription, date, thumbnailData, notes
  - Relationships: (none mentioned)

  Queries:
  // Fetch all results, sorted by date descending
  let fetchRequest: NSFetchRequest<AnalysisResultEntity> = ...
  fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
  let results = try context.fetch(fetchRequest)

  Third-party SDKs/libraries:

  1. MediaPipeTasksVision (0.10.14) (via CocoaPods)
    - FaceLandmarker: 478-point face mesh
    - ImageSegmenter: Multi-class segmentation
    - Models bundled: face_landmarker.task, selfie_multiclass_256x256.tflite
  2. No other external dependencies (pure iOS frameworks)

  Auth flows:

  Camera Permission Flow:
  AVCaptureDevice.requestAccess(for: .video) { granted in
      if granted {
          // Start camera session
      } else {
          // Show permission denied alert
      }
  }
  - First-time: System permission dialog
  - Denied: App shows custom alert with link to Settings
  - Granted: Stored in iOS privacy database, no re-prompting

  OpenAI API Authentication:
  request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
  - Static API key from ApiKeys.plist
  - No OAuth, no token refresh
  - Key validated on first API call (implicit)

  Webhooks, queues, event buses, messaging systems:

  NotificationCenter (Event Bus):

  Events posted:
  - "AnalysisResultReady": userInfo = ["result": AnalysisResult]
  - "PersonalizationReady": userInfo = ["personalizedData": PersonalizedSeasonData]
  - "PersonalizationFailed": userInfo = ["error": Error, "fallbackResult": AnalysisResult]
  - UIApplication.didReceiveMemoryWarningNotification: System event

  Observers:
  - RefactoredCameraViewController: Analysis/personalization events
  - SceneDelegate: Memory warnings

  NotificationManager (NotificationManager.swift):
  - 30-second timeout mechanism
  - Prevents stale notifications from being processed
  - Uses DispatchWorkItem for timeout handling

  File storage, analytics, feature flags, notifications, payments:

  File Storage:
  - Local only (no cloud storage)
  - Bundle resources: JSON files for seasons, colors, thresholds
  - Embedded models: face_landmarker.task, selfie_multiclass_256x256.tflite
  - Core Data SQLite database: Analysis results

  Analytics: Not implemented

  Feature Flags: Not implemented

  Push Notifications: Not implemented

  Payments/In-App Purchases: Not implemented

  ---
  8. User Interface Behavior

  Screens/pages/views/components:

  1. LandingPageView (LandingPageView.swift:1-150)
    - Components:
        - S13 logo/title at top
      - Scrollable grid of 4 season modules (Spring, Summer, Autumn, Winter)
      - Each module has 3 sub-season circles (abbreviated: brt, tru, drk, lgt, sft)
      - Animated gradient button at bottom (camera icon)
    - Behavior:
        - Tap sub-season circle → Present DefaultSeasonView modally
      - Tap camera button → Transition to camera view
      - Gradient animations loop infinitely
  2. RefactoredCameraViewController (RefactoredCameraViewController.swift:16-1122)
    - Components:
        - PreviewMetalView (full-screen camera preview)
      - Color labels (skin, hair, eye colors) - hidden by default
      - FrameQualityIndicatorView (quality bars for size/position/brightness/sharpness)
      - Analyze button (blue, 200x44, bottom center)
      - Debug overlay (3-finger tap to toggle)
      - Calibration UI (white reference guide, progress bar, skip button)
    - Behavior:
        - On appear: Start calibration mode
      - Calibration: Overlay with white reference guide appears
      - After calibration: Analysis mode, frame quality indicator updates real-time
      - Analyze button: Enabled only when quality ≥ 0.7
      - Tap analyze: Show loading spinner, stop frame processing, trigger analysis
      - On result: Present AnalysisResultView or PersonalizedSeasonView
  3. PersonalizedSeasonView (PersonalizedSeasonView.swift:1-300)
    - Components:
        - Header: Info button (left), Close button (right)
      - Color DNA section: Ring chart + explanation text
      - Enhanced color grids: Best Neutrals, Best Accents, Best Base Colors
      - Season Palette Explorer
      - Colors to Avoid grid
      - Modules grid (future expansion)
    - Behavior:
        - Info button → Present DefaultSeasonView as sheet
      - Close button → Dismiss to camera view
      - Color tap → Show color detail tooltip
      - DNA ring chart → Visual representation of season blend
  4. DefaultSeasonView (not read, but referenced)
    - Static season information
    - Characteristics, palette, styling recommendations
    - Dismiss to return
  5. AnalysisResultView (referenced, shows basic results)
    - Season assignment
    - Contrast bar
    - Dismiss/Retry/See Details buttons
  6. FrameQualityIndicatorView (FrameQualityIndicatorView.swift)
    - Real-time quality bars (horizontal colored bars)
    - Labels: Face Size, Position, Brightness, Sharpness
    - Colors: Green (good), Yellow (acceptable), Red (poor)
    - Overall quality message
  7. SeasonDNARingChart (SeasonDNARingChart.swift)
    - Concentric rings showing season influences
    - Primary (outer ring), Secondary (middle), Tertiary (inner)
    - Percentage labels
    - Color-coded per season

  Navigation structure:

  RootViewController (UIKit container)
  ├── LandingPageView (SwiftUI, visible initially)
  │   ├── Tap season → DefaultSeasonView (modal)
  │   └── Tap camera → RefactoredCameraViewController
  └── RefactoredCameraViewController (UIKit, hidden initially)
      ├── After analysis → PersonalizedSeasonView (modal sheet)
      │   └── Info button → DefaultSeasonView (sheet over sheet)
      └── Or → AnalysisResultView (modal sheet)
          └── See Details → PersonalizedSeasonView or DefaultSeasonView

  How UI components derive and mutate state:

  Deriving State (Read-only):
  // PersonalizedSeasonView
  var body: some View {
      let dna = viewModel.seasonDNA // Computed from personalizedData
      SeasonDNARingChart(seasonDNA: dna, ...)
  }

  Mutating State (User Actions):
  // RefactoredCameraViewController
  @objc private func analyzeButtonTapped() {
      isAnalyzeButtonPressed = true // Local state
      viewModel.analyzeCurrentFrame() // Triggers ViewModel action
  }

  Reactive Updates (Combine):
  // CameraViewModel publishes updates
  @Published private(set) var currentFrameQualityScore: QualityScore?

  // RefactoredCameraViewController receives updates
  func viewModel(_ viewModel: CameraViewModel, didUpdateFrameQuality quality: QualityScore) {
      DispatchQueue.main.async {
          self.frameQualityHostingController?.rootView = FrameQualityIndicatorView(qualityScore: quality)
          self.updateAnalyzeButtonState(isEnabled: quality.isAcceptableForAnalysis)
      }
  }

  Forms, validation, loading states, error states, empty states:

  Forms:
  - No traditional forms (no text input)
  - Camera positioning is the "input"

  Validation:
  - Frame quality validation (real-time)
  - Quality must meet thresholds before analysis enabled

  Loading States:
  // During analysis
  let loadingIndicator = UIActivityIndicatorView(style: .large)
  loadingIndicator.center = view.center
  loadingIndicator.startAnimating()
  view.addSubview(loadingIndicator)

  // Removed after result ready
  indicator.removeFromSuperview()

  Error States:
  // Camera permission denied
  presentCameraPermissionsDeniedAlert()

  // Analysis failed
  toastService.showToast("Unable to analyze. Please improve lighting and position.", type: .warning)

  // API timeout
  // Falls back to ColorDatabaseManager, shows PersonalizedSeasonView with fallback data

  Empty States:
  - No saved results: SavedResultsView shows empty list (not implemented in read files)
  - No face detected: Frame quality shows all zeros, analyze button disabled

  Conditional rendering and role-based behavior:

  Conditional Rendering:
  // PersonalizedSeasonView
  if let enhancedData = viewModel.personalizedData.enhancedColorData {
      // Show AI-enhanced colors
  } else {
      // Show legacy color recommendations
  }

  if !viewModel.personalizedData.colorsToAvoid.isEmpty {
      // Show colors to avoid section
  }

  No Role-Based Behavior (single-user app, no accounts)

  Debug-Only Features:
  #if DEBUG
  addDebugPersonalizedSeasonButton()
  #endif

  ---
  9. Business Logic

  Core rules implemented in code:

  1. 12-Season Classification Rules (SeasonClassifier.swift:415-443)
  let seasonRules: [SeasonRule] = [
      SeasonRule(name: "Light Spring", lRange: 65...90, cRange: 40...55, hueRange: 60...90),
      SeasonRule(name: "True Spring", lRange: 55...70, cRange: 50...65, hueRange: 50...80),
      // ... 10 more rules
  ]
    - Each season has defined ranges for Lightness (L*), Chroma (C*), and Hue (degrees)
    - Classification uses fuzzy matching via dimensionScore
    - Best match wins
  2. Frame Quality Acceptance Criteria (FrameQualityService.swift:8-21)
  static let minimumQualityScoreForAnalysis: Float = 0.7
  static let minimumFaceSizeScoreForAnalysis: Float = 0.6
  static let minimumFacePositionScoreForAnalysis: Float = 0.7
  static let minimumBrightnessScoreForAnalysis: Float = 0.6
    - All thresholds must be met simultaneously
    - Analysis button enabled only when isAcceptableForAnalysis == true
  3. White Balance Calibration (ColorExtractor.swift:27-54)
  static func calculate(from referenceColor: (r, g, b)) -> WhiteBalanceCalibration {
      let maxChannel = max(r, max(g, b))
      return WhiteBalanceCalibration(
          redFactor: maxChannel / r,
          greenFactor: maxChannel / g,
          blueFactor: maxChannel / b
      )
  }
    - Uses max channel normalization (not 255 reference)
    - Preserves exposure better than absolute white reference
  4. Season DNA Blend Detection (PersonalizedSeasonData.swift:362-412)
  private func createFallbackSeasonDNA() -> SeasonDNA {
      let modifier = seasonName.components(separatedBy: " ").first?.lowercased()
      switch modifier {
      case "soft": secondarySeason = detectSoftSecondary(baseSeason)
      case "clear", "bright": secondarySeason = detectClearSecondary(baseSeason)
      // ...
      }
  }
    - Parses detailed season name to infer secondary influences
    - "Soft Summer" → Primary: Soft Summer (85%), Secondary: Soft Autumn (15%)

  Validation rules:

  1. Color Value Validation:
    - RGB: Clamped to 0-255 range
    - Lab: L (0-100), a/b (-128 to 127)
    - Hex colors: Validated for 3, 6, or 8 character format with #
  2. Confidence Score Validation:
    - Clamped to 0.0-1.0 range
    - SeasonWeight initialization: max(0.0, min(1.0, weight))
  3. Segmentation Mask Validation:
    - Class IDs: 0-255 (UInt8)
    - Mask dimensions must match frame dimensions
  4. API Response Validation:
    - JSON structure must match schema exactly
    - Missing fields → Fallback to ColorDatabaseManager

  Computation logic:

  1. CIEDE2000 Delta-E Calculation (ColorConverters.swift - implementation inferred):
  ΔE2000 = sqrt[(ΔL'/kL*SL)² + (ΔC'/kC*SC)² + (ΔH'/kH*SH)² + RT*(ΔC'/kC*SC)*(ΔH'/kH*SH)]
    - Perceptually uniform color difference
    - Accounts for lightness, chroma, hue differences
    - Rotation term (RT) for blue hues
  2. Dimension Score (Fuzzy Matching) (SeasonClassifier.swift:399-405)
  func dimensionScore(value: Float, rangeMin: Float, rangeMax: Float) -> Float {
      let mid = (rangeMin + rangeMax) / 2.0
      let half = (rangeMax - rangeMin) / 2.0
      let dist = abs(value - mid)
      return max(0.0, 1 - (dist / half))
  }
    - Returns 1.0 at range center, 0.0 at boundaries
    - Linear falloff
    - Final season score = average of L/C/H dimension scores
  3. Contrast Calculation (ContrastCalculator.swift - inferred):
  skinHairContrast = deltaE2000(skinLab, hairLab) * 0.5
  skinEyeContrast = deltaE2000(skinLab, eyeLab) * 0.3
  hairEyeContrast = deltaE2000(hairLab, eyeLab) * 0.2
  totalContrast = skinHairContrast + skinEyeContrast + hairEyeContrast
    - Weighted by perceptual importance
    - Skin-hair relationship is most significant
  4. FPS Calculation (CameraViewModel.swift:210-214)
  frameCount += 1
  if currentTime - lastFPSUpdateTime >= 1.0 {
      currentFPS = Float(frameCount) / Float(currentTime - lastFPSUpdateTime)
      frameCount = 0
      lastFPSUpdateTime = currentTime
  }
    - Updates every 1 second
    - Counts frames processed in interval

  Permissioning/authorization rules:

  Camera Access:
  AVCaptureDevice.authorizationStatus(for: .video)
  // .authorized → Allow camera use
  // .denied → Show settings alert
  // .notDetermined → Request permission
  // .restricted → Show unavailable message

  No user-level permissions (single-user app)

  Workflow branching logic:

  Analysis Result Routing (SeasonViewNavigationManager.swift inferred):
  Analysis Complete →
  ├── PersonalizedSeasonData available? → PersonalizedSeasonView
  └── PersonalizedSeasonData unavailable → DefaultSeasonView (with AnalysisResult data)

  Personalization Workflow Branching (PersonalizationService.swift:194-210):
  generateDNAPersonalization() →
  ├── API key configured?
  │   ├── Yes → Check network
  │   │   ├── Available → Make API request
  │   │   │   ├── Success → Parse PersonalizedSeasonData
  │   │   │   └── Failure/Timeout → createEnhancedFallback()
  │   │   └── Unavailable → createEnhancedFallback()
  │   └── No → createEnhancedFallback()

  Feature toggles and configuration-driven behavior:

  AppConfiguration (AppConfiguration.swift inferred):
  class AppConfiguration {
      var isPersonalizationActive: Bool {
          return getOpenAIKey() != nil
      }

      func getOpenAIKey() -> String? {
          return APIKeyManager.getOpenAIAPIKey()
      }
  }

  Thresholds Configuration (thresholds.json → SeasonClassifier.swift:124-146):
  {
    "warmCoolThreshold": 12.0,
    "lightDarkThreshold": 65.0,
    "brightThreshold": 40.0,
    "softThreshold": 35.0
  }
  - Loaded from JSON, falls back to hardcoded defaults if file missing
  - Allows tuning classification without code changes

  Debug Features (RefactoredCameraViewController.swift:1092-1121):
  #if DEBUG
  func addDebugPersonalizedSeasonButton() {
      // Bottom-left button for mock data testing
  }
  #endif

  ---
  10. Infrastructure and Environment Behavior

  Build/runtime configuration:

  Xcode Project Settings (inferred from project structure):
  - Deployment Target: iOS 14.0 minimum (Podfile), iOS 16.0 for some Swift Package features
  - Build Configurations: Debug, Release
  - Code Signing: Automatic (standard iOS app)
  - Bitcode: Disabled (MediaPipe incompatibility)
  - Swift Version: 5.9+

  CocoaPods Configuration (Podfile inferred):
  platform :ios, '14.0'
  use_frameworks!

  target 'ImageSegmenter' do
    pod 'MediaPipeTasksVision', '~> 0.10.14'
  end

  Swift Package Manager (Package.swift exists but content not fully read):
  - Minimum platform: iOS 16.0
  - Used alongside CocoaPods

  Environment variables:

  Console Logging Control (AppDelegate.swift:8-10):
  setenv("OS_ACTIVITY_MODE", "disable", 1) // Disable OS activity filtering
  setenv("OS_ACTIVITY_DT_MODE", "YES", 1) // Enable diagnostic logging
  setenv("CFLOG_LEVEL", "DEBUG", 1) // Set Core Foundation log level

  API Key from Bundle (ApiKeys.plist):
  <plist>
    <dict>
      <key>OPENAI_API_KEY</key>
      <string>sk-proj-...</string>
    </dict>
  </plist>
  - Not an environment variable, but configuration file
  - Excluded from version control via .gitignore

  Deployment assumptions visible in code:

  1. Device Requirements:
    - Metal-capable device (for GPU rendering)
    - Rear camera (for analysis) or front camera (fallback)
    - iOS 14.0+ operating system
    - Sufficient storage for Core Data (minimal)
  2. Network Assumptions:
    - Internet access for OpenAI API (optional)
    - HTTPS connectivity
    - No proxy support mentioned
  3. Bundle Assumptions:
    - MediaPipe models included in app bundle (not downloaded)
    - Season JSON files in Resources/Seasons/
    - colors.json in Resources/
    - ApiKeys.plist in main bundle root

  Logging, monitoring, error handling:

  Logging Services (LoggingService.swift, DebugLogger.swift):
  LoggingService.info("MESSAGE")
  LoggingService.warning("MESSAGE")
  LoggingService.error("MESSAGE")
  LoggingService.debug("MESSAGE")
  LoggingService.verbose("MESSAGE")

  Log Output:
  - Console output via print(), NSLog(), fputs(stderr)
  - Structured prefixes for categorization (e.g., "CALIBRATION_FLOW:", "COLOR_FLOW:")

  Error Handling Patterns:
  // Try-catch for synchronous errors
  do {
      let data = try Data(contentsOf: url)
  } catch {
      print("Error: \(error)")
      // Fallback logic
  }

  // Completion handlers for async errors
  completion: (Result<T, Error>) -> Void

  // Delegate callbacks for runtime errors
  func viewModel(_ viewModel: CameraViewModel, didEncounterError error: Error)

  No external monitoring (no Crashlytics, Sentry, etc.)

  Dev vs test vs production differences:

  Debug-Only Features:
  #if DEBUG
  print("Debug log message")
  addDebugPersonalizedSeasonButton()
  printConfigurationStatus()
  #endif

  No separate test/production builds mentioned (single binary, behavior controlled by API key presence)

  Likely Production Differences (not explicitly coded):
  - Release build: Optimizations enabled, asserts removed
  - Debug build: Additional logging, debug UI elements

  ---
  11. Security and Reliability Considerations

  Authentication and authorization model:

  No User Authentication:
  - Single-user, local-only app
  - No accounts, no passwords
  - No session tokens

  Camera Authorization:
  - System-level: AVCaptureDevice.requestAccess
  - Stored by iOS, not by app
  - Re-prompted if reset in Settings > Privacy > Camera

  API Authorization:
  - OpenAI API: Bearer token (static key)
  - Key stored in ApiKeys.plist (excluded from git)
  - No key rotation mechanism
  - No user-specific keys

  Sensitive data handling:

  Personal Data Collected:
  1. Facial Images: Processed in real-time, not stored (unless explicitly saved by user as thumbnail)
  2. Facial Landmarks: Transient, not persisted
  3. Color Measurements: Stored in Core Data (Lab values, RGB tuples)
  4. Analysis Results: Stored locally in Core Data (season assignment, thumbnail)

  Data Protection Measures:
  - No network transmission of raw images (only Lab color values sent to OpenAI)
  - Local Core Data encrypted when device locked (iOS standard)
  - No cloud backup of sensitive data (unless user enables iCloud)
  - No analytics/telemetry collecting personal data

  API Key Security:
  ApiKeys.plist → .gitignore → Not committed to repository
  ApiKeys.example.plist → Committed (shows structure, no real key)
  - Risk: If ApiKeys.plist is accidentally committed, key is exposed
  - Mitigation: .gitignore prevents accidental commits
  - Best Practice: Use environment variables or keychain (not implemented)

  Trust boundaries:

  User Device (Trusted)
  ├── App Sandbox (Trusted)
  │   ├── Core Data (Encrypted at rest)
  │   ├── MediaPipe Models (Bundled, read-only)
  │   └── Color Extraction (In-memory)
  └── External Network (Untrusted)
      └── OpenAI API (TLS 1.2+, HTTPS only)

  Trust Assumptions:
  - iOS system frameworks are secure
  - MediaPipe library is not malicious
  - OpenAI API is trustworthy
  - User's device is not jailbroken/compromised

  Error recovery:

  Camera Session Errors (CameraViewModel.swift:494-512):
  func sessionWasInterrupted(canResumeManually: Bool) {
      isSessionRunning = false
      clearServices()
      delegate?.viewModelDidDetectSessionInterruption(self, canResume: canResumeManually)
  }

  func sessionInterruptionEnded() {
      isSessionRunning = true
      configureInitialServices()
      delegate?.viewModelDidResumeSession(self)
  }
  - Recovery: Automatic resume when interruption ends
  - Manual Resume: User can tap "Resume" button if manual resumption required

  MediaPipe Processing Errors (CameraViewModel.swift:599-607):
  func faceLandmarkerService(_:, didFinishLandmarkDetection result:, error:) {
      if let error = error {
          delegate?.viewModel(self, didEncounterError: error)
          return
      }
      // Continue processing
  }
  - Recovery: Log error, skip frame, continue processing next frame

  API Timeout/Failure (PersonalizationService.swift:528-558):
  if nsError.code == NSURLErrorTimedOut {
      if attempt < maxRetryAttempts {
          DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
              self?.makeOpenAIRequestWithRetry(..., attempt: attempt + 1, ...)
          }
          return
      }
  }
  // After retries exhausted: Fall back to ColorDatabaseManager
  - Recovery: 2 retry attempts, then local database fallback

  Retry logic:

  1. OpenAI API Retries (PersonalizationService.swift:31-33, 486-558):
    - Max Attempts: 2
    - Delay: 2 seconds between attempts
    - Conditions: Only retry on NSURLErrorTimedOut
    - Fallback: createEnhancedFallback() after exhausting retries
  2. No Retries for:
    - Camera capture errors (user must manually resume)
    - MediaPipe inference errors (skip frame, no retry)
    - Core Data errors (show error, no auto-retry)

  Failure modes:

  1. Camera Unavailable:
    - Cause: Permission denied, hardware failure, session interruption
    - Effect: cameraUnavailableLabel shown, resumeButton visible
    - Recovery: User grants permission or manually resumes
  2. MediaPipe Model Missing:
    - Cause: Bundle corruption, missing file
    - Effect: FaceLandmarkerService/ImageSegmenterService fail to initialize
    - Recovery: None (app unusable for analysis, would require reinstall)
  3. Analysis Fails (Insufficient Quality):
    - Cause: Poor lighting, no face detected, motion blur
    - Effect: analyzeButton disabled, quality feedback shown
    - Recovery: User improves conditions and retries
  4. Personalization Fails:
    - Cause: API key missing, network down, API timeout/error
    - Effect: Fallback to ColorDatabaseManager, show PersonalizedSeasonView with basic data
    - Recovery: Automatic fallback (transparent to user)
  5. Core Data Save Fails:
    - Cause: Disk full, database corruption
    - Effect: Error logged, analysis result not saved
    - Recovery: User can re-analyze (data lost)
  6. Memory Pressure:
    - Cause: Intensive processing, many textures allocated
    - Effect: SceneDelegate receives memory warnings
    - Recovery: Clear object pools (TexturePoolManager, BufferPoolManager, PixelBufferPoolManager)

  Potential reliability risks visible from code:

  1. Memory Leaks:
    - Risk: Retain cycles in closures (delegates, completion handlers)
    - Mitigation: Extensive use of [weak self] in closures
    - Remaining Risk: Some closures may still have strong captures
  2. Texture Pool Exhaustion:
    - Risk: TexturePoolManager max 10 textures, high-resolution frames may need more
    - Mitigation: Pool cleared on memory warnings
    - Remaining Risk: Pool may still exhaust under extreme load
  3. API Key Exposure:
    - Risk: ApiKeys.plist accidentally committed to public repo
    - Mitigation: .gitignore
    - Remaining Risk: Human error, key could still leak
  4. Single-Threaded UI Updates:
    - Risk: Heavy processing on main thread could freeze UI
    - Mitigation: Background queue for frame processing, DispatchQueue.main.async for UI updates
    - Remaining Risk: Some delegate callbacks may still block main thread
  5. No Network Error UI:
    - Risk: API calls fail silently (user sees fallback data without knowing why)
    - Mitigation: Fallback provides reasonable user experience
    - Remaining Risk: User doesn't know they're not getting AI-powered results
  6. Core Data Concurrency:
    - Risk: Multiple threads accessing NSManagedObjectContext
    - Mitigation: Not visible in code (assumed to use main queue context)
    - Remaining Risk: If background saves added later, need performBlock

  ---
  12. Dependency Map

  Most important internal dependencies:

  Critical Path (Analysis Workflow):
  RefactoredCameraViewController
      ↓ owns
  CameraViewModel
      ↓ uses
  CameraService → AVFoundation (camera capture)
  SegmentationService → MediaPipe (face detection/segmentation)
  ClassificationService → SeasonClassifier (season determination)
  PersonalizationService → OpenAI API (personalization)
  CoreDataManager → Core Data (persistence)

  Supporting Services:
  ColorExtractor → ColorConverters (color space conversion)
  FrameQualityService → FrameQualityEvaluator (quality assessment)
  ColorDatabaseManager → colors.json (fallback recommendations)
  NotificationManager → NotificationCenter (cross-module communication)

  Most important external dependencies:

  1. MediaPipe (0.10.14) - Critical
    - Face landmark detection (478 points)
    - Multi-class image segmentation
    - Failure Impact: App cannot perform analysis
    - Alternatives: Vision framework (less accurate), TensorFlow Lite (more work)
  2. Metal - Critical
    - GPU rendering of camera preview
    - Texture processing for segmentation
    - Failure Impact: No camera preview, reduced performance
    - Alternatives: Core Graphics (slower), Core Image (less control)
  3. OpenAI API - Important but Non-Critical
    - AI-powered personalization
    - Failure Impact: Falls back to ColorDatabaseManager (acceptable UX)
    - Alternatives: Local LLM (too large for mobile), rule-based recommendations (implemented as fallback)
  4. AVFoundation - Critical
    - Camera capture
    - Failure Impact: Cannot capture video, app unusable
    - Alternatives: None for iOS camera access
  5. Core Data - Important
    - Analysis result persistence
    - Failure Impact: No saved history
    - Alternatives: UserDefaults (limited), SQLite directly, Realm

  Which modules are tightly coupled:

  Tight Coupling:

  1. CameraViewModel ↔ CameraService
    - CameraViewModel creates and owns CameraService
    - Direct delegate callbacks
    - Reason: Camera lifecycle tied to ViewModel lifecycle
  2. ColorExtractor ↔ SegmentationService
    - ColorExtractor requires segmentation masks from SegmentationService
    - Shared texture cache
    - Reason: Color extraction cannot work without segmentation
  3. RefactoredCameraViewController ↔ CameraViewModel
    - ViewController owns ViewModel
    - Implements multiple delegate protocols
    - Updates UI based on ViewModel state
    - Reason: MVVM tight binding (by design)
  4. PersonalizedSeasonView ↔ PersonalizedSeasonViewModel
    - View owns ViewModel via @StateObject
    - View observes ViewModel @Published properties
    - Reason: SwiftUI MVVM pattern

  Loose Coupling (Good):

  1. ClassificationService ↔ PersonalizationService
    - ClassificationService calls PersonalizationService via protocol
    - Delegate pattern allows substitution
    - Reason: Service-oriented design
  2. Services ↔ Core Data
    - Services use CoreDataManager facade
    - No direct NSManagedObjectContext access
    - Reason: Repository pattern

  Which modules appear reusable or isolated:

  Highly Reusable Modules:

  1. ColorConverters (ColorConverters.swift)
    - Pure color space conversion functions
    - No dependencies on app-specific logic
    - Reusability: Could be extracted to standalone library
  2. ContrastCalculator (ContrastCalculator.swift)
    - CIEDE2000 implementation
    - Lab color difference calculations
    - Reusability: Standalone color science utility
  3. SeasonClassifier (SeasonClassifier.swift)
    - Season classification logic
    - Depends only on ColorConverters
    - Reusability: Could power web app or other platforms with season JSON
  4. ColorDatabaseManager (ColorDatabaseManager.swift)
    - JSON-based color lookup
    - No iOS-specific dependencies (likely)
    - Reusability: Cross-platform color database
  5. Object Pools (BufferPoolManager, TexturePoolManager)
    - Generic pooling pattern
    - Reusability: Applicable to any high-frequency allocation scenario

  Moderately Reusable:

  1. FrameQualityService
    - Frame quality assessment logic
    - Depends on CVPixelBuffer (iOS-specific)
    - Reusability: Could be ported to other video analysis apps
  2. PersonalizationService
    - OpenAI API integration
    - Reusability: Generic prompt-based AI service (with modifications)

  Tightly Coupled (Low Reusability):

  1. CameraViewModel
    - Orchestrates entire camera workflow
    - Depends on many app-specific services
    - Reusability: Low, very app-specific
  2. RefactoredCameraViewController
    - UIKit/SwiftUI hybrid
    - Tightly coupled to CameraViewModel
    - Reusability: Low

  ---
  13. End-to-End Flows

  Flow 1: App Launch

  Initiating Trigger: User taps app icon

  Sequence:
  1. iOS launches app process
     └─> main() → @main AppDelegate

  2. AppDelegate.application(_:didFinishLaunchingWithOptions:)
     └─> Configure console logging (disable OS filtering)
     └─> Log app start
     └─> Return true

  3. AppDelegate.application(_:configurationForConnecting:options:)
     └─> Return UISceneConfiguration("Default Configuration")

  4. SceneDelegate.scene(_:willConnectTo:options:)
     └─> Rely on Main.storyboard for UI

  5. Main.storyboard instantiation
     └─> Load RootViewController as initial VC

  6. RootViewController.viewDidLoad()
     ├─> setupRefactoredCameraViewController()
     │   ├─> Instantiate from storyboard
     │   ├─> Set inferenceResultDeliveryDelegate = self
     │   ├─> Add as child VC
     │   └─> Add view to tabBarContainerView (hidden)
     │
     └─> setupLandingPageViewController()
         ├─> Create LandingPageView (SwiftUI)
         ├─> Wrap in UIHostingController
         ├─> Add as child VC
         ├─> Add view to tabBarContainerView (visible)
         └─> Hide camera view, send to back

  7. RefactoredCameraViewController.viewDidLoad()
     ├─> setupNotificationManager()
     ├─> setupColorLabels() (hidden)
     ├─> setupFrameQualityUI()
     ├─> setupDebugOverlay() (hidden)
     ├─> setupCalibrationUI()
     ├─> Initialize CameraViewModel
     │   └─> CameraViewModel.init()
     │       ├─> Set delegates (cameraService, segmentationService, classificationService)
     │       └─> configureInitialServices()
     │           ├─> configureSegmentationService()
     │           │   └─> Load selfie_multiclass_256x256.tflite model
     │           └─> configureFaceLandmarkerService()
     │               └─> Load face_landmarker.task model
     └─> viewModel.delegate = self

  8. RefactoredCameraViewController.viewDidAppear(_:)
     └─> (Skipped initially because view is hidden)

  9. UI Displayed: LandingPageView visible

  Data Passed:
  - None (initialization only)

  State Mutations:
  - AppDelegate: Logging configured
  - RootViewController: Child VCs added
  - CameraViewModel: Services configured, mode = .calibration
  - UI: LandingPageView visible

  Final Output:
  Landing page displayed with season exploration modules and camera button.

  ---
  Flow 2: User Performs Color Analysis

  Initiating Trigger: User taps camera button on LandingPageView

  Sequence:
  1. LandingPageView: onAnalyzeButtonTapped() called
     └─> RootViewController.showCameraView()
         ├─> Set cameraVC.shouldAutoStartAnalysis = true
         ├─> UIView.transition (cross-dissolve animation)
         │   ├─> landingVC.view.isHidden = true
         │   └─> cameraVC.view.isHidden = false
         └─> cameraVC.prepareAndStartCameraIfNeeded()
             └─> viewModel.startCamera()

  2. CameraViewModel.startCamera()
     ├─> configureInitialServices() (ensure models loaded)
     └─> cameraService.startLiveCameraSession { configuration in
         │   └─> [AVCaptureSession configured and started]
         └─> On success:
             ├─> isSessionRunning = true
             ├─> delegate?.viewModelDidStartCamera(self)
             └─> RefactoredCameraViewController: Hide unavailable label

  3. RefactoredCameraViewController.viewDidAppear(_:)
     └─> viewModel.startCalibrationMode()
         ├─> currentMode = .calibration
         ├─> shouldProcessFrames = false
         ├─> calibrationFrameCount = 0
         └─> delegate?.viewModel(self, didEnterCalibrationMode: true)
             └─> Show calibrationOverlayView

  4. User: Position white reference card, tap "Capture White Reference"
     └─> RefactoredCameraViewController.captureWhiteReference()
         └─> viewModel.captureWhiteReference()
             ├─> isDetectingWhiteReference = true
             └─> (Camera already running)

  5. CameraService: Capture frames, call delegate
     └─> CameraViewModel.didOutput(sampleBuffer:orientation:)
         └─> backgroundQueue.async {
             │   processFrame(sampleBuffer:orientation:timeStamps:)
             │
             ├─> currentPixelBuffer = pixelBuffer
             ├─> delegate?.viewModel(self, didUpdateSegmentedBuffer: pixelBuffer)
             │   └─> PreviewMetalView updates display
             │
             └─> if currentMode == .calibration && isDetectingWhiteReference
                 └─> processCalibrationFrame()
                     ├─> Create texture from pixelBuffer
                     ├─> extractWhiteReferenceColor(from: texture, region: centerRegion)
                     │   └─> Calculate average RGB in center 10% box
                     ├─> calibrationAccumulator.append((r, g, b))
                     ├─> calibrationFrameCount += 1
                     ├─> delegate?.viewModel(self, didUpdateCalibrationProgress: progress)
                     │   └─> UI: Update calibrationProgressView
                     │
                     └─> if calibrationFrameCount >= 5
                         └─> finalizeCalibration()
                             ├─> Calculate average white color from 5 frames
                             ├─> whiteBalanceCalibration = WhiteBalanceCalibration.calculate(from: avgColor)
                             ├─> segmentationService.setWhiteBalanceCalibration(calibration)
                             ├─> isCalibrated = true
                             ├─> currentMode = .analysis
                             ├─> shouldProcessFrames = true
                             └─> delegate?.viewModel(self, didCompleteCalibration: calibration)
                                 └─> UI: Fade out calibration overlay

  6. Analysis Mode: Frames processed continuously
     └─> CameraViewModel.processFrame(sampleBuffer:orientation:timeStamps:)
         ├─> Throttle to 100ms intervals
         ├─> frameCount++ (for FPS calculation)
         │
         ├─> faceLandmarkerService.detectLandmarksAsync(sampleBuffer:...)
         │   └─> MediaPipe processes asynchronously
         │   └─> Callback: faceLandmarkerService(_:didFinishLandmarkDetection:error:)
         │       ├─> lastFaceLandmarks = landmarks
         │       ├─> segmentationService.updateFaceLandmarks(landmarks)
         │       └─> delegate?.viewModel(self, didUpdateFaceLandmarks: landmarks)
         │
         └─> segmentationService.processFrame(sampleBuffer:...)
             ├─> Convert sampleBuffer to MPImage
             ├─> imageSegmenterService.segment(mpImage:orientation:)
             │   └─> MediaPipe inference returns CategoryMask
             ├─> Render segmentation to outputPixelBuffer
             ├─> colorExtractor.extractColorsOptimized(from: texture, segmentMask:...)
             │   └─> Extract skin, hair, eye colors using landmarks and mask
             │   └─> Apply white balance correction
             │   └─> lastColorInfo = ColorInfo(skinColor:..., hairColor:..., ...)
             │
             ├─> Create SegmentationResult(outputPixelBuffer, colorInfo, faceBoundingBox)
             └─> delegate?.segmentationService(self, didCompleteSegmentation: result)
                 └─> CameraViewModel: currentColorInfo = result.colorInfo
                 └─> delegate?.viewModel(self, didUpdateColorInfo: colorInfo)
                     └─> RefactoredCameraViewController: updateColorDisplay(colorInfo)
                 │
                 └─> Calculate frame quality:
                     ├─> FrameQualityService.evaluateFrameQualityWithLandmarks(pixelBuffer:landmarks:imageSize:)
                     │   ├─> faceSizeScore (weighted 0.25)
                     │   ├─> facePositionScore (weighted 0.25)
                     │   ├─> brightnessScore (weighted 0.30)
                     │   ├─> sharpnessScore (weighted 0.20)
                     │   └─> overall = weighted average
                     │
                     └─> delegate?.viewModel(self, didUpdateFrameQuality: qualityScore)
                         └─> RefactoredCameraViewController:
                             ├─> Update frameQualityHostingController.rootView
                             └─> updateAnalyzeButtonState(isEnabled: quality.isAcceptableForAnalysis)
                                 └─> analyzeButton.isEnabled = (overall >= 0.7 && all thresholds met)

  7. User: Position face, wait for quality to reach threshold, tap "Analyze"
     └─> RefactoredCameraViewController.analyzeButtonTapped()
         ├─> Guard: quality.isAcceptableForAnalysis == true
         ├─> Show UIActivityIndicatorView (loading spinner)
         └─> viewModel.analyzeCurrentFrame()
             └─> classificationService.analyzeFrame(pixelBuffer: currentPixelBuffer, colorInfo: currentColorInfo)

  8. ClassificationService.analyzeFrame(pixelBuffer:colorInfo:)
     ├─> Convert colors to Lab space:
     │   ├─> skinLab = ColorUtils.convertRGBToLab(skinColor)
     │   ├─> hairLab = ColorUtils.convertRGBToLab(hairColor)
     │   └─> eyeLab = ColorUtils.convertRGBToLab(averageEyeColor)
     │
     ├─> ContrastCalculator.analyzeContrast(skinColor:hairColor:eyeColor:)
     │   └─> Calculate CIEDE2000 delta-E values, weighted average
     │   └─> Return ContrastResult(value, level, description)
     │
     ├─> SeasonClassifier.classifySeason(skinLab:hairLab:)
     │   ├─> Calculate L, C, H from Lab values
     │   │   ├─> L = skinLab.L
     │   │   ├─> C = sqrt(a² + b²)
     │   │   └─> H = atan2(b, a) * 180/π
     │   │
     │   ├─> classifySeasonWithConfidence(lightness:chroma:hue:)
     │   │   └─> For each seasonRule in seasonRules:
     │   │       ├─> lScore = dimensionScore(L, rule.lRange)
     │   │       ├─> cScore = dimensionScore(C, rule.cRange)
     │   │       ├─> hScore = dimensionScore(H, rule.hueRange)
     │   │       └─> avgScore = (lScore + cScore + hScore) / 3
     │   │   └─> Return (bestSeason: "True Summer", confidence: 0.82)
     │   │
     │   └─> Return ClassificationResult(detailedSeason: .trueSummer, macroSeason: .summer, confidence: 0.82, ...)
     │
     ├─> Create thumbnail: UIImage from pixelBuffer
     │
     ├─> Create AnalysisResult(season: .summer, detailedSeasonName: "True Summer", confidence: 0.82, skinColor:..., 
  hairColor:..., ...)
     │
     ├─> delegate?.classificationService(self, didCompleteAnalysis: result)
     │   └─> CameraViewModel: stopFrameProcessing()
     │   └─> NotificationManager.postAnalysisResult(result, from: self)
     │       └─> NotificationCenter.post("AnalysisResultReady", userInfo: ["result": result])
     │           └─> RefactoredCameraViewController.handleAnalysisResultReady(_:)
     │               ├─> Remove loading spinner
     │               └─> presentAnalysisResultView(result: result)
     │                   └─> (Held until personalization completes)
     │
     └─> attemptPersonalization(for: result, detailedSeason: "True Summer")
         ├─> Load season data: loadSeasonData(for: "True Summer")
         │   └─> Bundle.main.url(forResource: "True Summer", withExtension: "json")
         │   └─> Decode JSON into Season struct
         │
         └─> personalizationService.generateDNAPersonalization(for: result, seasonData: seasonData, detailedSeasonName: "True 
  Summer") { result in ... }

  9. PersonalizationService.generateDNAPersonalization(...)
     ├─> Create DNA-enhanced prompt:
     │   └─> createDNAPersonalizationPrompt(analysisResult:seasonData:detailedSeasonName:)
     │       ├─> Include user's Lab color values
     │       ├─> Include season characteristics
     │       └─> Request JSON with SeasonDNA, EnhancedColorRecommendations
     │
     ├─> Check API key: AppConfiguration.shared.getOpenAIKey()
     │   └─> If nil → createEnhancedFallback() [Jump to step 10]
     │
     ├─> Check network: isNetworkAvailable()
     │   └─> If unavailable → createEnhancedFallback() [Jump to step 10]
     │
     └─> generateResponsesAPIPersonalization(...)
         └─> makeOpenAIRequestWithRetry(apiKey:prompt:attempt:1:completion:)
             ├─> Create URLRequest to https://api.openai.com/v1/chat/completions
             ├─> Set Authorization: Bearer <API_KEY>
             ├─> Set timeout: 45 seconds
             ├─> Request body:
             │   {
             │     "model": "gpt-4o",
             │     "messages": [
             │       {"role": "system", "content": "You are an expert color analyst..."},
             │       {"role": "user", "content": "USER'S MEASURED COLORS:\n- Skin Lab: L:72.5, a:8.3, b:15.2\n..."}
             │     ],
             │     "max_tokens": 5000,
             │     "temperature": 0.7,
             │     "response_format": {"type": "json_object"}
             │   }
             │
             └─> URLSession.shared.dataTask(with: request) { data, response, error in
                 │
                 ├─> On timeout (error.code == NSURLErrorTimedOut):
                 │   ├─> If attempt < 2: Retry after 2 seconds
                 │   └─> Else: completion(.failure(error)) → createEnhancedFallback()
                 │
                 ├─> On HTTP 200:
                 │   ├─> Parse JSON response
                 │   ├─> Extract choices[0].message.content
                 │   └─> parseDNAPersonalizationResponse(response:analysisResult:detailedSeasonName:completion:)
                 │       ├─> JSON.parse(content)
                 │       ├─> Extract seasonDNA, enhancedColorData, colorRecommendations
                 │       ├─> parseDNAJSONToPersonalizedData(json:...)
                 │       │   ├─> Create SeasonDNA(primary:secondary:tertiary:...)
                 │       │   ├─> Create EnhancedColorRecommendations(bestNeutrals:bestAccents:bestBaseColors:)
                 │       │   └─> Create PersonalizedSeasonData(baseSeason:..., seasonDNAData:..., enhancedColorData:...)
                 │       │
                 │       └─> completion(.success(personalizedData))
                 │           └─> ClassificationService: delegate?.classificationService(self, didCompletePersonalization: 
  personalizedData)
                 │               └─> CameraViewModel: NotificationManager.postPersonalizationReady(personalizedData, from: self)
                 │                   └─> NotificationCenter.post("PersonalizationReady", userInfo: ["personalizedData": 
  personalizedData])
                 │                       └─> RefactoredCameraViewController.handlePersonalizationReady(_:)
                 │                           └─> presentPersonalizationResultView(result: .success)
                 │                               └─> (Proceed to step 11)
                 │
                 └─> On error:
                     └─> completion(.failure(error))
                         └─> ClassificationService: delegate?.classificationService(self, didFailPersonalization: error, 
  fallbackResult: analysisResult)
                             └─> CameraViewModel: NotificationManager.postPersonalizationFailed(error, fallbackResult: 
  analysisResult, from: self)
                                 └─> NotificationCenter.post("PersonalizationFailed", ...)
                                     └─> RefactoredCameraViewController.handlePersonalizationFailed(_:)
                                         └─> presentPersonalizationResultView(result: .failure)
                                             └─> (Proceed to fallback in step 10)

  10. Fallback Path: PersonalizationService.createEnhancedFallback(analysisResult:detailedSeasonName:)
      ├─> createFallbackSeasonDNA(from: analysisResult, detailedSeasonName: "True Summer")
      │   ├─> Parse season name: "True Summer" → ["True", "Summer"]
      │   ├─> Modifier "true" → No secondary season (pure match)
      │   └─> Return SeasonDNA(primary: SeasonWeight("True Summer", 1.0), secondary: nil, tertiary: nil, explanation: "Pure True 
  Summer", ...)
      │
      ├─> createFallbackEnhancedColors(seasonDNA:)
      │   ├─> ColorDatabaseManager.findMatchingColors(for: "True Summer", category: "Neutrals")
      │   │   └─> Parse colors.json, filter by season + category
      │   │   └─> Return [ColorItem(name:"Almond", hexValue:"#efdece", usageContext:"...", harmonyReason:"..."), ...]
      │   ├─> Repeat for "Accents", "Base"
      │   └─> Return EnhancedColorRecommendations(bestNeutrals:..., bestAccents:..., bestBaseColors:...)
      │
      └─> Return PersonalizedSeasonData(baseSeason:"True Summer", seasonDNAData:fallbackDNA, enhancedColorData:fallbackColors, 
  ...)
          └─> completion(.success(fallbackData))
              └─> (Continue to step 11)

  11. Display Results: RefactoredCameraViewController.presentAnalysisResultView(result:) or 
  presentPersonalizationResultView(result:)
      ├─> Stop camera: viewModel.stopCamera()
      ├─> Clear preview: previewView.pixelBuffer = nil
      ├─> Update analysisViewModel: analysisViewModel.updateWithResult(result)
      │
      ├─> Determine which view to show:
      │   ├─> If PersonalizedSeasonData available:
      │   │   └─> Create PersonalizedSeasonView(personalizedData:...)
      │   │       └─> UIHostingController wraps SwiftUI view
      │   └─> Else:
      │       └─> Create AnalysisResultView(viewModel:...)
      │
      └─> Present modal sheet:
          └─> present(hostingController, animated: true)
              └─> PersonalizedSeasonView displayed with:
                  ├─> Season DNA ring chart (primary/secondary/tertiary)
                  ├─> Enhanced color grids (Best Neutrals, Accents, Base Colors)
                  ├─> Season Palette Explorer
                  ├─> Colors to Avoid
                  └─> Dismiss button → Return to camera view

  12. User: Tap dismiss button
      └─> presentationMode.wrappedValue.dismiss()
          └─> Modal dismissed
          └─> Back to RefactoredCameraViewController (analysis mode)
          └─> If shouldAutoStartAnalysis == true:
              └─> viewModel.startCamera() → Resume frame processing

  Data Passed Between Steps:
  - CMSampleBuffer → CVPixelBuffer → MTLTexture
  - Segmentation mask (UInt8 array)
  - Face landmarks ([NormalizedLandmark])
  - ColorInfo (skin/hair/eye RGB and Lab)
  - QualityScore (overall, faceSize, facePosition, brightness, sharpness)
  - AnalysisResult (season, confidence, colors, contrast, thumbnail)
  - PersonalizedSeasonData (DNA, enhanced colors, recommendations)

  State Mutations:
  - CameraViewModel.currentMode: .calibration → .analysis
  - CameraViewModel.whiteBalanceCalibration: nil → WhiteBalanceCalibration(...)
  - CameraViewModel.isCalibrated: false → true
  - CameraViewModel.shouldProcessFrames: false → true → false (during analysis)
  - RefactoredCameraViewController.analyzeButton.isEnabled: false → true (when quality met)
  - UI: Landing page → Camera view → Calibration overlay → Analysis mode → Results modal

  Final Output:
  PersonalizedSeasonView displayed with AI-generated or fallback recommendations, Season DNA visualization, enhanced color grids.
   User can dismiss to return to camera view or navigate to default season information.

  ---
  14. Hidden Assumptions and Inferred Design Decisions

  What the original developers appear to have optimized for:

  1. Real-Time Performance:
    - Object pooling (BufferPoolManager, TexturePoolManager)
    - GPU-accelerated processing via Metal
    - Frame throttling (100ms intervals)
    - Early termination in quality evaluation
    - Tradeoff: Complexity increased for performance gains
  2. Color Accuracy:
    - Lab color space (perceptually uniform)
    - CIEDE2000 (state-of-the-art color difference)
    - White balance calibration
    - Tradeoff: More complex than RGB-based analysis
  3. User Experience:
    - Real-time quality feedback
    - Graceful fallbacks (API → ColorDatabase)
    - Smooth animations and transitions
    - Tradeoff: More code for error handling
  4. Modularity:
    - Service-oriented architecture
    - Protocol-based communication
    - Service extensions for large modules
    - Tradeoff: More files, more indirection

  Architectural tradeoffs visible in code:

  1. MVVM with Delegates vs Pure Combine:
    - Choice: Mix of Combine (@Published) and delegates
    - Tradeoff: Delegates for complex callbacks (errors, multi-param), Combine for simple state
    - Benefit: Flexibility
    - Cost: Inconsistency in communication patterns
  2. UIKit + SwiftUI Hybrid:
    - Choice: UIKit for camera/Metal, SwiftUI for results
    - Tradeoff: UIKit better for low-level control, SwiftUI for rapid UI development
    - Benefit: Best of both worlds
    - Cost: UIHostingController overhead, more complex navigation
  3. On-Device Processing vs Cloud:
    - Choice: All MediaPipe processing on-device
    - Tradeoff: Privacy + offline capability vs battery/performance
    - Benefit: No data sent to servers (except Lab colors to OpenAI)
    - Cost: Limited to device capabilities, drains battery
  4. Embedded Models vs Dynamic Download:
    - Choice: Bundle MediaPipe models in app
    - Tradeoff: Larger app size (~20 MB) vs runtime downloads
    - Benefit: Works offline, no download delays
    - Cost: Larger initial download
  5. Local Database Fallback vs API-Only:
    - Choice: colors.json as fallback when API fails
    - Tradeoff: Larger app bundle vs API dependency
    - Benefit: Always functional, even without internet
    - Cost: 80 KB additional bundle size

  Conventions or implicit contracts the system relies on:

  1. Season JSON Schema Contract:
    - All season JSON files must have exact structure: { "Season Name": { name, tagline, characteristics, palette, styling } }
    - Breaking this contract → loadSeasonData() fails → createMockSeason() fallback
  2. MediaPipe Output Stability:
    - Assumes segmentation class IDs are stable (3 = skin, etc.)
    - Assumes 478 landmark points in consistent order
    - Breaking this → ColorExtractor would extract wrong regions
  3. OpenAI JSON Response Schema:
    - Expects exact structure: { personalizedTagline, userCharacteristics, seasonDNA: { primary: { season, weight }, ... }, 
  enhancedColorData: { ... } }
    - Breaking this → Parse fails → createEnhancedFallback()
  4. Color Database Format:
    - colors.json must be array of { name, hexValue, category, season }
    - Breaking this → ColorDatabaseManager fails → Recommendations empty
  5. Coordinate System Assumptions:
    - Face landmarks in normalized coordinates (0-1 range)
    - Origin at top-left
    - Breaking this → Face position calculations incorrect
  6. Calibration White Reference Assumptions:
    - User positions actual white card in center 10% box
    - Lighting is consistent before/after calibration
    - Breaking this → White balance correction is inaccurate

  Parts of the system that seem fragile, incomplete, or highly coupled:

  Fragile:

  1. NotificationCenter Timeout Mechanism (NotificationManager.swift):
    - 30-second hardcoded timeout
    - If notification arrives at 29.9 seconds, processed
    - If arrives at 30.1 seconds, ignored silently
    - Risk: User sees stale results or no results
  2. API Key Management:
    - ApiKeys.plist can be accidentally committed
    - No runtime validation of key format
    - Risk: Exposed key, API abuse
  3. Core Data Schema Evolution:
    - No migration strategy mentioned
    - Adding new fields to AnalysisResult requires careful migration
    - Risk: Data loss on app update
  4. Metal Texture Cache:
    - Relies on CVMetalTextureCache automatic management
    - No explicit flush except on memory warnings
    - Risk: Texture cache exhaustion under heavy load

  Incomplete:

  1. No User Profiles:
    - SavedResultsView mentioned but implementation not fully visible
    - No way to organize results by person
    - Missing: Multi-user support
  2. No Analytics:
    - No tracking of analysis success rate
    - No monitoring of API failure rates
    - Missing: Observability
  3. No A/B Testing:
    - Classification thresholds hardcoded or from single JSON
    - No experimentation framework
    - Missing: Data-driven optimization
  4. No Undo/Redo:
    - Analysis result immediately saved to Core Data
    - No way to discard/retry without deleting
    - Missing: User flexibility

  Highly Coupled:

  1. ColorExtractor ↔ SegmentationService:
    - ColorExtractor requires specific segmentation class IDs
    - Tightly coupled to MediaPipe output format
    - Risk: Changing segmentation model breaks color extraction
  2. PersonalizedSeasonView ↔ PersonalizedSeasonData:
    - View assumes specific structure of PersonalizedSeasonData
    - Multiple levels of optional unwrapping
    - Risk: Adding new fields requires view updates
  3. ClassificationService ↔ PersonalizationService:
    - ClassificationService directly instantiates PersonalizationService
    - Hardcoded service dependency
    - Risk: Difficult to test independently

  ---
  15. Unknowns and Open Questions

  Missing files or context needed for higher confidence:

  1. Core Data Model Schema:
    - File: ImageSegmenter.xcdatamodeld (not read)
    - Unknown: Exact entity structure, relationships, migration policies
    - Impact on Analysis: Cannot confirm persistence schema
  2. Metal Shader Implementations:
    - Files: Shaders.metal, DownsamplingShader.metal, ColorConversionShader.metal (not read in detail)
    - Unknown: Exact GPU algorithms for color conversion, segmentation rendering
    - Impact: Cannot explain GPU processing details
  3. Storyboard Structure:
    - Files: Main.storyboard, LaunchScreen.storyboard (not read, binary format)
    - Unknown: Exact UI layout, constraints, segue connections
    - Impact: Cannot explain UIKit view hierarchy fully
  4. PersonalizationService+ResponsesAPI.swift:
    - File: PersonalizationService+ResponsesAPI.swift (mentioned but not read)
    - Unknown: Responses API integration details, potential differences from chat completions API
    - Impact: May have alternative API implementation not covered
  5. DefaultSeasonView Implementation:
    - File: DefaultSeasonView.swift (referenced but not fully read)
    - Unknown: Complete UI structure, interactions
    - Impact: Cannot fully explain fallback view behavior
  6. SavedResultsView Implementation:
    - File: SavedResultsView.swift (mentioned, not read)
    - Unknown: How results are fetched from Core Data, list UI
    - Impact: Cannot explain historical results workflow
  7. Test Files:
    - Files: ColorConvertersTests.swift, SeasonClassifierTests.swift, ResponsesAPIWorkflowTests.swift (not read in detail)
    - Unknown: Test coverage, edge cases validated
    - Impact: Cannot confirm system behavior under all conditions

  Ambiguities in behavior:

  1. Season JSON Loading Priority:
    - ClassificationService tries bundle root, then Resources/Seasons/, then Seasons/
    - Ambiguity: What if same season file exists in multiple locations?
    - Assumption: First found wins (bundle root priority)
  2. API Timeout Retry Logic:
    - Retries only on NSURLErrorTimedOut
    - Ambiguity: What about NSURLErrorNetworkConnectionLost or other network errors?
    - Assumption: Other errors → immediate fallback (no retry)
  3. Frame Processing Order:
    - Landmarks and segmentation both run on same frame
    - Ambiguity: Which completes first? Does segmentation wait for landmarks?
    - Assumption: Both run concurrently, segmentation uses landmarks if available
  4. Calibration Skip Behavior:
    - User can skip calibration
    - Ambiguity: Does analysis quality suffer without calibration?
    - Assumption: WhiteBalanceCalibration.identity (1.0 factors) → no correction
  5. Color Extraction Algorithm Selection:
    - ColorExtractor.extractColorsOptimized calls extractColorsHighAccuracy in production
    - Ambiguity: Is there a fast mode for lower-end devices?
    - Assumption: Always uses high accuracy, no device-dependent branching

  Areas where runtime behavior cannot be proven from static analysis alone:

  1. MediaPipe Model Accuracy:
    - Cannot determine actual landmark detection accuracy without running
    - Cannot measure segmentation precision without ground truth data
    - Static Analysis Limitation: Model quality is empirical
  2. Metal Shader Performance:
    - Cannot measure GPU utilization, frame render times
    - Cannot determine texture cache hit rates
    - Static Analysis Limitation: GPU profiling required
  3. Core Data Migration Success:
    - Cannot confirm migration works without upgrading app
    - Cannot verify data integrity after schema changes
    - Static Analysis Limitation: Runtime testing needed
  4. OpenAI API Response Variability:
    - Cannot predict API response times (network-dependent)
    - Cannot guarantee JSON schema compliance (LLM output varies)
    - Static Analysis Limitation: API behavior is non-deterministic
  5. Memory Pressure Handling:
    - Cannot determine actual memory usage under load
    - Cannot confirm object pools prevent OOM crashes
    - Static Analysis Limitation: Profiling required
  6. Camera Interruption Scenarios:
    - Cannot test all interruption types (phone calls, Siri, FaceTime)
    - Cannot verify resume behavior for all cases
    - Static Analysis Limitation: Real-device testing needed
  7. Color Database Fallback Quality:
    - Cannot compare AI recommendations vs database recommendations
    - Cannot measure user satisfaction with fallback
    - Static Analysis Limitation: User testing required
  8. Edge Cases in Color Extraction:
    - Cannot predict behavior with extreme skin tones (very dark/light)
    - Cannot test with unusual hair colors (green, purple)
    - Static Analysis Limitation: Diverse test data needed

  ---
  16. Final Structured Output for Another LLM

  A. Concise System Map (Bullet Form)

  - App Name: Season13 (iOS 14.0+, Xcode 16.3, Swift 5.9+)
  - Purpose: Determine user's seasonal color palette (12-season system) via real-time facial analysis
  - Core Technologies: MediaPipe (face detection/segmentation), Metal (GPU rendering), OpenAI GPT-4o-mini (personalization)
  - Architecture: MVVM with Combine, service-oriented business logic, protocol-based communication
  - Key Modules:
    - Camera & Video: AVFoundation capture, Metal rendering, real-time preview
    - Face Analysis: MediaPipe 478-point landmarker, multi-class segmentation (skin/hair/eyes)
    - Color Science: Lab color space, CIEDE2000 delta-E, white balance calibration
    - Classification: 12-season rule-based matcher (lightness/chroma/hue ranges)
    - AI Personalization: OpenAI API with Season DNA (primary/secondary/tertiary influences), fallback to local color database
    - UI: SwiftUI + UIKit hybrid, landing page, camera view, personalized results
    - Persistence: Core Data for analysis history
  - Data Flow: Camera → MediaPipe → Color Extraction → Classification → AI Personalization → UI Display → Core Data
  - Security: On-device processing, no raw images sent to servers, API key in git-ignored plist
  - Performance: Object pooling, GPU acceleration, frame throttling (100ms), early termination in quality eval

  ---
  B. Glossary of Important Modules/Entities

  | Module/Entity                  | Purpose                                                                      | Key Files
                          |
  |--------------------------------|------------------------------------------------------------------------------|--------------
  ------------------------|
  | RootViewController             | Root navigation container, manages landing/camera view transitions           |
  RootViewController.swift             |
  | LandingPageView                | Home screen with season exploration modules                                  |
  LandingPageView.swift                |
  | RefactoredCameraViewController | Camera capture UI, quality indicators, analysis trigger                      |
  RefactoredCameraViewController.swift |
  | CameraViewModel                | Orchestrates camera session, frame processing, analysis workflow             |
  CameraViewModel.swift                |
  | CameraService                  | Manages AVCaptureSession, camera permissions, frame output                   |
  CameraService.swift                  |
  | FaceLandmarkerService          | Wraps MediaPipe face landmarker (478 points)                                 |
  FaceLandmarkerService.swift          |
  | SegmentationService            | Coordinates MediaPipe segmentation, color extraction, quality eval           |
  SegmentationService.swift            |
  | ImageSegmenterService          | Executes MediaPipe multi-class segmentation inference                        |
  ImageSegmenterService.swift          |
  | ColorExtractor                 | Extracts skin/hair/eye colors from segmentation mask, applies white balance  |
  ColorExtractor.swift                 |
  | ColorConverters                | RGB ↔ Lab ↔ HSV conversions, CIEDE2000 implementation                        |
  ColorConverters.swift                |
  | SeasonClassifier               | 12-season classification via lightness/chroma/hue fuzzy matching             |
  SeasonClassifier.swift               |
  | ClassificationService          | Orchestrates color analysis, season determination, personalization trigger   |
  ClassificationService.swift          |
  | PersonalizationService         | OpenAI API integration, generates AI-powered recommendations with Season DNA |
  PersonalizationService.swift         |
  | ColorDatabaseManager           | Local JSON color database, fallback recommendations                          |
  ColorDatabaseManager.swift           |
  | FrameQualityService            | Evaluates frame suitability (face size, position, brightness, sharpness)     |
  FrameQualityService.swift            |
  | CoreDataManager                | Persistence facade, saves/loads AnalysisResult entities                      |
  CoreDataManager.swift                |
  | PersonalizedSeasonView         | Displays AI-powered results with DNA ring chart, enhanced color grids        |
  PersonalizedSeasonView.swift         |
  | DefaultSeasonView              | Displays static season information from JSON                                 |
  DefaultSeasonView.swift              |
  | AnalysisResult                 | Core data model: season, colors (RGB+Lab), contrast, confidence, thumbnail   |
  AnalysisResult.swift                 |
  | PersonalizedSeasonData         | AI-generated recommendations with Season DNA, enhanced colors                |
  PersonalizedSeasonData.swift         |
  | Season                         | Static season definition: characteristics, palette, styling                  | Season.swift
                          |
  | SeasonDNA                      | Primary/secondary/tertiary season influences with weights                    |
  PersonalizedSeasonData.swift         |
  | WhiteBalanceCalibration        | White balance correction factors (R/G/B multipliers)                         |
  ColorExtractor.swift                 |

  ---
  C. Machine-Friendly JSON Summary

  {
    "app_purpose": "iOS application for seasonal color analysis using computer vision and AI, determining user's optimal color 
  palette from 12-season system based on facial features",

    "architecture": {
      "pattern": "MVVM with Combine framework",
      "communication": ["Delegate pattern", "Combine publishers", "NotificationCenter events"],
      "layers": [
        "Presentation (SwiftUI/UIKit)",
        "ViewModel (State management)",
        "Service (Business logic)",
        "Model (Data structures)",
        "Infrastructure (iOS frameworks)"
      ]
    },

    "entry_points": [
      {
        "name": "App Launch",
        "file": "AppDelegate.swift",
        "method": "application(_:didFinishLaunchingWithOptions:)",
        "triggers": "iOS app launch"
      },
      {
        "name": "Camera Analysis",
        "file": "RefactoredCameraViewController.swift",
        "method": "analyzeButtonTapped()",
        "triggers": "User taps Analyze button"
      },
      {
        "name": "Season Exploration",
        "file": "LandingPageView.swift",
        "method": "onSubSeasonTapped(_:)",
        "triggers": "User taps season module"
      }
    ],

    "modules": [
      {
        "name": "Camera & Video Processing",
        "files": ["CameraService.swift", "CameraViewModel.swift", "RefactoredCameraViewController.swift",
  "PreviewMetalView.swift"],
        "responsibility": "Capture live video, manage AVFoundation session, render with Metal",
        "dependencies": ["AVFoundation", "Metal", "MediaPipe"],
        "key_functions": ["startCamera()", "processFrame(sampleBuffer:orientation:timeStamps:)",
  "didOutput(sampleBuffer:orientation:)"]
      },
      {
        "name": "Face Detection & Segmentation",
        "files": ["FaceLandmarkerService.swift", "ImageSegmenterService.swift", "SegmentationService.swift"],
        "responsibility": "Detect 478 facial landmarks, perform multi-class segmentation",
        "dependencies": ["MediaPipeTasksVision 0.10.14", "Metal"],
        "key_functions": ["detectLandmarksAsync()", "segment(mpImage:orientation:)",
  "processFrame(sampleBuffer:orientation:timeStamps:)"]
      },
      {
        "name": "Color Extraction & Analysis",
        "files": ["ColorExtractor.swift", "ColorConverters.swift", "ContrastCalculator.swift"],
        "responsibility": "Extract colors from facial regions, convert color spaces, calculate contrast",
        "dependencies": ["Metal", "MediaPipe landmarks", "WhiteBalanceCalibration"],
        "key_functions": ["extractColorsOptimized(from:segmentMask:width:height:)", "colorToLab(_:)",
  "analyzeContrast(skinColor:hairColor:eyeColor:)"]
      },
      {
        "name": "Season Classification",
        "files": ["SeasonClassifier.swift", "ClassificationService.swift"],
        "responsibility": "Classify into 12 seasons via lightness/chroma/hue fuzzy matching",
        "dependencies": ["ColorConverters", "ContrastCalculator"],
        "key_functions": ["classify(skinColor:hairColor:)", "classifySeasonWithConfidence(lightness:chroma:hue:)", "dimensionScore(value:rangeMin:rangeMax:)"]
    "dimensionScore(value:rangeMin:rangeMax:)"]
          },
          {
            "name": "AI Personalization",
            "files": ["PersonalizationService.swift", "PersonalizationService+DNAHelpers.swift",
      "PersonalizationService+Parsing.swift", "ColorDatabaseManager.swift"],
            "responsibility": "Generate AI-powered recommendations via OpenAI API with Season DNA analysis and local fallback",
            "dependencies": ["OpenAI API", "colors.json database"],
            "key_functions": ["fetchPersonalization(for:)", "parsePersonalizationResponse(_:)",
      "generateFallbackRecommendations(for:)"]
          },
          {
            "name": "Frame Quality Assessment",
            "files": ["FrameQualityService.swift", "FrameQualityEvaluator.swift"],
            "responsibility": "Evaluate frame suitability via face size, position, brightness, sharpness metrics",
            "dependencies": ["MediaPipe landmarks"],
            "key_functions": ["evaluateFrameQuality(pixelBuffer:faceBoundingBox:imageSize:)",
      "evaluateFrameQualityWithLandmarks(pixelBuffer:landmarks:imageSize:)"]
          },
          {
            "name": "UI/Presentation",
            "files": ["RefactoredCameraViewController.swift", "PersonalizedSeasonView.swift", "LandingPageView.swift",
      "DefaultSeasonView.swift", "SeasonDNARingChart.swift"],
            "responsibility": "Display camera UI, quality indicators, analysis results, season exploration",
            "dependencies": ["CameraViewModel", "PersonalizationService", "Season models"],
            "key_functions": ["analyzeButtonTapped()", "presentPersonalizationResultView(result:)", "showDefaultSeasonView(for:)"]
          },
          {
            "name": "Data Persistence",
            "files": ["Core Data model", "AnalysisResult.swift", "PersonalizedSeasonData.swift"],
            "responsibility": "Store analysis results with thumbnails in Core Data",
            "dependencies": ["Core Data framework"],
            "key_functions": ["NSSecureCoding conformance", "thumbnail generation"]
          }
        ],
        "domain_entities": [
          {
            "name": "AnalysisResult",
            "type": "struct",
            "purpose": "Complete analysis outcome with season, colors, contrast, confidence",
            "key_fields": ["season", "detailedSeasonName", "confidence", "skinColorLab", "hairColorLab", "eyeColorLab",
      "skinHairContrast", "skinEyeContrast", "thumbnail"]
          },
          {
            "name": "PersonalizedSeasonData",
            "type": "struct",
            "purpose": "AI-generated personalization with Season DNA and enhanced color data",
            "key_fields": ["seasonDNA", "enhancedColorData", "metalRecommendations", "stylingTips", "makeupRecommendations"]
          },
          {
            "name": "SeasonDNA",
            "type": "struct",
            "purpose": "Primary/secondary/tertiary seasonal influences with weights and explanation",
            "key_fields": ["primary: SeasonWeight", "secondary: SeasonWeight?", "tertiary: SeasonWeight?", "explanation",
      "isPureMatch"]
          },
          {
            "name": "ColorItem",
            "type": "struct",
            "purpose": "Individual color with hex, usage context, harmony reasoning",
            "key_fields": ["name", "hexValue", "usageContext", "harmonyReason", "isRecommended"]
          },
          {
            "name": "WhiteBalanceCalibration",
            "type": "struct",
            "purpose": "RGB scaling factors for white reference normalization",
            "key_fields": ["redFactor", "greenFactor", "blueFactor"]
          },
          {
            "name": "QualityScore",
            "type": "struct",
            "purpose": "Frame quality metrics for analysis suitability",
            "key_fields": ["overall", "faceSize", "facePosition", "brightness", "sharpness", "isAcceptableForAnalysis",
      "feedbackMessage"]
          },
          {
            "name": "Season",
            "type": "struct",
            "purpose": "Static season definition loaded from JSON resources",
            "key_fields": ["name", "characteristics", "palette", "stylingRecommendations"]
          }
        ],
        "state_management": {
          "pattern": "MVVM with Combine",
          "key_viewmodels": [
            {
              "name": "CameraViewModel",
              "responsibility": "Orchestrate camera workflow, frame processing pipeline, calibration/analysis modes",
              "published_state": ["currentMode", "isCalibrated", "shouldProcessFrames", "qualityScore", "colorInfo",
      "analysisResult"],
              "state_transitions": [
                "idle → calibration (on camera start)",
                "calibration → analyzing (after white balance set)",
                "analyzing → processing (on analyze button)",
                "processing → idle (after result displayed)"
              ]
            }
          ],
          "data_flow": "Unidirectional: View → ViewModel → Services → ViewModel (via Combine publishers) → View",
          "persistence": "Core Data for AnalysisResult storage"
        },
        "api_integrations": [
          {
            "name": "OpenAI Chat Completions API",
            "endpoint": "https://api.openai.com/v1/chat/completions",
            "model": "gpt-4o-mini",
            "purpose": "Generate personalized Season DNA analysis and color recommendations",
            "authentication": "Bearer token from ApiKeys.plist",
            "timeout": "45 seconds",
            "retry_strategy": "2 attempts with exponential backoff",
            "fallback": "ColorDatabaseManager uses colors.json for static recommendations",
            "request_format": {
              "messages": [
                {"role": "system", "content": "Season expert prompt with DNA instructions"},
                {"role": "user", "content": "Analysis data including season, Lab colors, contrast metrics"}
              ],
              "max_tokens": 5000,
              "temperature": 0.7
            }
          }
        ],
        "core_flows": [
          {
            "name": "Initial Calibration Flow",
            "trigger": "Camera view appears",
            "steps": [
              "1. CameraViewModel enters calibration mode",
              "2. User presents white reference card to camera",
              "3. ColorExtractor.extractWhiteReferenceColor() samples center region",
              "4. WhiteBalanceCalibration.calculate() computes RGB factors (maxChannel method)",
              "5. ColorExtractor.setWhiteBalance() marks calibrated = true",
              "6. CameraViewModel transitions to analyzing mode",
              "7. Frame processing begins with white-balanced color extraction"
            ],
            "exit_conditions": ["White balance factors computed and applied"]
          },
          {
            "name": "Frame Processing Pipeline",
            "trigger": "Every 100ms during analyzing mode",
            "steps": [
              "1. CameraService outputs CMSampleBuffer",
              "2. CameraViewModel.processFrame() throttles to 100ms intervals",
              "3. Parallel async operations:",
              "   a. FaceLandmarkerService detects 478 landmarks",
              "   b. ImageSegmenterService segments face regions (skin/hair/eyes/lips/eyebrows)",
              "   c. FrameQualityService evaluates quality metrics",
              "   d. ColorExtractor extracts colors with white balance applied",
              "   e. FPS calculation",
              "4. CameraViewModel publishes updated colorInfo and qualityScore",
              "5. UI displays real-time quality indicators"
            ],
            "exit_conditions": ["User taps analyze button", "User stops camera"]
          },
          {
            "name": "Season Analysis Flow",
            "trigger": "User taps analyze button",
            "steps": [
              "1. CameraViewModel.analyzeButtonTapped() validates calibration and quality",
              "2. CameraViewModel transitions to processing mode",
              "3. ClassificationService.classifySeasonComplete() called with current colorInfo",
              "4. ColorConverters converts RGB → Lab color space",
              "5. SeasonClassifier.classifySeasonWithConfidence() computes fuzzy matches against 12 season rules",
              "6. ContrastCalculator computes CIEDE2000 Delta-E between features",
              "7. AnalysisResult created with top season, confidence, Lab colors, contrasts",
              "8. PersonalizationService.fetchPersonalization() called",
              "9. OpenAI API request sent with season and color data",
              "10. Response parsed for SeasonDNA and color recommendations",
              "11. PersonalizedSeasonData published via NotificationCenter",
              "12. RefactoredCameraViewController presents PersonalizedSeasonView",
              "13. Result saved to Core Data with thumbnail"
            ],
            "exit_conditions": ["PersonalizedSeasonView displayed", "Error shown if analysis fails"]
          },
          {
            "name": "Season DNA Generation",
            "trigger": "OpenAI API response received OR fallback triggered",
            "steps": [
              "1. PersonalizationService parses JSON response",
              "2. SeasonDNA extracted with primary (0.6-0.85), secondary (0.15-0.35), tertiary (0.05-0.15) weights",
              "3. If weights missing, DNAHelpers infers from season name patterns:",
              "   - 'Light' seasons → secondary influence from adjacent light season",
              "   - 'Soft' seasons → secondary influence from adjacent soft season",
              "   - 'True' seasons → pure matches (primary > 85%)",
              "4. EnhancedColorData parsed with detailed ColorItem recommendations",
              "5. PersonalizedSeasonData constructed and returned",
              "6. UI displays SeasonDNARingChart and EnhancedColorGrid"
            ],
            "exit_conditions": ["PersonalizedSeasonData complete", "Fallback to legacy colorRecommendations if parsing fails"]
          }
        ],
        "business_rules": [
          {
            "rule": "White Balance Required",
            "description": "All color extraction must use calibrated white balance; analysis blocked until calibration complete",
            "enforcement": "ColorExtractor.isCalibrated guard, CameraViewModel.analyzeButtonTapped() validation"
          },
          {
            "rule": "Quality Thresholds",
            "description": "Frame must meet minimum scores: overall ≥ 0.7, faceSize ≥ 0.6, facePosition ≥ 0.7, brightness ≥ 0.6",
            "enforcement": "FrameQualityService.minimumQualityScoreForAnalysis constants, QualityScore.isAcceptableForAnalysis
      computed property"
          },
          {
            "rule": "Season DNA Weight Constraints",
            "description": "Primary: 0.6-0.85, Secondary: 0.15-0.35, Tertiary: 0.05-0.15; weights must sum to 1.0; pure matches when
      primary > 0.85",
            "enforcement": "OpenAI API prompt instructions, DNAHelpers fallback generation logic"
          },
          {
            "rule": "12-Season Classification",
            "description": "Must classify into exactly one of: Light/True/Bright Spring, Light/True/Soft Summer, Soft/True/Dark
      Autumn, Bright/True/Dark Winter",
            "enforcement": "SeasonClassifier.seasonRules array (12 SeasonRule entries), classifySeasonWithConfidence() returns top
      match"
          },
          {
            "rule": "Lab Color Space for Analysis",
            "description": "All season classification uses Lab (L*a*b*) color space for perceptual uniformity, not RGB/HSV",
            "enforcement": "ColorConverters.rgbToLab() conversion before classification, SeasonClassifier operates on Lab values"
          },
          {
            "rule": "CIEDE2000 Contrast Calculation",
            "description": "Contrast between facial features measured via CIEDE2000 Delta-E (perceptually accurate), not simple RGB
      difference",
            "enforcement": "ContrastCalculator.calculateCIEDE2000DeltaE() used for all contrast metrics in AnalysisResult"
          },
          {
            "rule": "Frame Processing Throttling",
            "description": "Process frames maximum once per 100ms to balance responsiveness and performance",
            "enforcement": "CameraViewModel.processFrame() timestamp comparison"
          },
          {
            "rule": "API Retry Strategy",
            "description": "OpenAI API requests retry up to 2 times (3 total attempts) before falling back to local database",
            "enforcement": "PersonalizationService.maxRetryAttempts = 2, ColorDatabaseManager fallback on failure"
          }
        ],
        "security_model": {
          "api_key_storage": "ApiKeys.plist (excluded from git via .gitignore)",
          "camera_permissions": "NSCameraUsageDescription in Info.plist, runtime permission request via
      AVCaptureDevice.requestAccess",
          "data_storage": "Core Data local storage (no cloud sync mentioned), AnalysisResult thumbnails stored as PNG data",
          "network_security": "HTTPS for OpenAI API (https://api.openai.com)",
          "secure_coding": "NSSecureCoding conformance for AnalysisResult Core Data storage",
          "known_risks": [
            "API key in plist could be extracted from app bundle",
            "No authentication/encryption mentioned for Core Data",
            "No mention of certificate pinning for API requests",
            "White reference calibration could be gamed to manipulate results"
          ]
        },
        "unknowns": [
          "Core Data schema details (entity names, relationships, attributes) - .xcdatamodeld not analyzed",
          "Metal shader implementations for GPU processing - .metal files not examined",
          "Complete MediaPipe model behavior - only TFLite model files present, internals opaque",
          "Test coverage percentage - test files identified but not all analyzed",
          "App Store deployment configuration - provisioning profiles, code signing details",
          "Analytics/crash reporting integration - no obvious references found",
          "Accessibility implementation beyond basic labels",
          "Localization/internationalization support - no .strings files observed",
          "Memory usage limits and optimization targets",
          "Detailed error recovery for Core Data failures",
          "Offline mode behavior when API unavailable for extended periods",
          "User data retention policies and deletion mechanisms",
          "Performance benchmarks and optimization goals",
          "A/B testing or feature flag infrastructure"
        ]
      }

