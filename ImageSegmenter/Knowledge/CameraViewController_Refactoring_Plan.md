# CameraViewController Refactoring Plan

## Current Issues

The `CameraViewController` has several significant issues that need to be addressed:

- **Size**: At over 1,290 lines of code, the class violates the Single Responsibility Principle
- **Multiple Responsibilities**: The class currently handles:
  - Camera setup and configuration
  - Frame processing and segmentation
  - UI management (error toasts, debug overlay)
  - Classification logic
  - Performance monitoring
  - Error handling
- **Thread Safety Issues**: UI updates from background threads causing warnings and potential crashes
- **Memory Management Concerns**: Potential leaks from improper buffer handling
- **Poor Testability**: Difficult to unit test due to tight coupling of responsibilities

## Proposed Architecture

We'll refactor to a proper MVVM (Model-View-ViewModel) architecture:

```
App
├── Views
│   ├── CameraView (UI only)
│   ├── ErrorToastView (extracted)
│   ├── DebugOverlayView (extracted)
│   └── AnalysisResultView (already separate)
├── ViewModels
│   ├── CameraViewModel (business logic)
│   └── AnalysisViewModel (classification logic)
├── Services
│   ├── CameraService (camera setup and frame delivery)
│   ├── SegmentationService (face/hair detection)
│   ├── ClassificationService (season determination)
│   ├── FrameQualityService (already separate)
│   ├── PerformanceMonitoringService (new)
│   └── ToastService (error message management)
└── Models
    ├── AnalysisResult (already exists)
    ├── FrameData (raw frame + metadata)
    ├── SegmentationResult (segmentation output)
    └── QualityScore (already exists)
```

## Refactoring Strategy

### Phase 1: Extract Services

1. **Create CameraService**
   - Extract camera setup, configuration, and session management
   - Implement frame delivery via delegation
   - Move AVCaptureSession handling here

2. **Extract SegmentationService**
   - Move segmentation model handling logic
   - Create clear interfaces for input/output
   - Proper buffer management

3. **Create ClassificationService**
   - Extract season classification logic
   - Move color analysis from renderer to this service

4. **Create ToastService**
   - Extract error toast functionality
   - Ensure all UI updates happen on main thread
   - Add queuing for multiple messages

### Phase 2: Create ViewModels

1. **Create CameraViewModel**
   - Handle coordination between services
   - Maintain application state
   - Process service outputs

2. **Create AnalysisViewModel**
   - Handle analysis result state
   - Prepare data for display

### Phase 3: Refine Views

1. **Simplify CameraViewController**
   - Reduced to UI configuration and event handling
   - Observe ViewModel state changes
   - No direct service interactions

2. **Extract ErrorToastView**
   - Standalone, reusable component
   - Self-contained animation logic

3. **Refine DebugOverlayView**
   - Completely separate SwiftUI component
   - Data-driven updates

### Phase 4: Improve Performance and Memory Management

1. **Implement Cache Strategy**
   - Proper buffer pooling
   - Limit history size

2. **Optimize Metal Code**
   - Extract to dedicated MetalRenderingService
   - Improve resource management

## Implementation Plan

### Week 1: Service Extraction

- Day 1-2: Extract CameraService
- Day 3-4: Extract SegmentationService
- Day 5: Create unit tests for services

### Week 2: View Models and UI Components

- Day 1-2: Create ViewModels
- Day 3-4: Extract UI components
- Day 5: Implement proper binding between components

### Week 3: Refinement and Testing

- Day 1-2: Optimize memory management
- Day 3: Add performance monitoring
- Day 4-5: End-to-end testing and bug fixes

## Benefits

- **Improved Maintainability**: Smaller, focused classes
- **Better Testability**: Services can be mocked for testing
- **Reduced Memory Issues**: Proper resource management
- **Thread Safety**: Clear boundaries for UI updates
- **Future Development**: Easier to extend with new features

## Potential Challenges

- **Breaking Changes**: Ensuring functionality remains during transition
- **Performance Impact**: Ensuring service communication doesn't impact performance
- **Learning Curve**: Team adaptation to new architecture
- **Refactoring Time**: Balancing refactoring with new feature development

## Success Metrics

- Code size reduction (each class under 300 lines)
- Memory usage reduction (20%+ improvement)
- Elimination of thread warnings
- Successful unit test coverage (80%+)
- UI responsiveness improvement (measure frame drops) 