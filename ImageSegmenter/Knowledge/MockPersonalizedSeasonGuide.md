# Mock PersonalizedSeasonView Testing Guide

This guide explains how to use the mock data system to test and debug PersonalizedSeasonView without performing full analyses.

## Quick Start

### 1. Add Debug Button (Recommended)

In your `RefactoredCameraViewController.swift`, add this to `viewDidLoad()`:

```swift
#if DEBUG
override func viewDidLoad() {
    super.viewDidLoad()
    // ... existing code ...
    
    // Add debug button for easy testing
    addDebugPersonalizedSeasonButton()
}
#endif
```

This adds a "🧪 Mock Personalized" button that opens a menu with different test scenarios.

### 2. Direct Usage

```swift
// Present with random mock data
DebugPersonalizedSeasonHelper.presentMockPersonalizedView(from: self)

// Present with specific mock data
let mockData = MockPersonalizedSeasonDataFactory.brightSpringWithBlend()
DebugPersonalizedSeasonHelper.presentMockPersonalizedView(mockData: mockData, from: self)
```

### 3. SwiftUI Previews

Use the provided preview in Xcode:
- Open `DebugPersonalizedSeasonHelper.swift`
- Use the SwiftUI preview to see live updates as you modify the view

## Available Mock Scenarios

### 1. Bright Spring with DNA Blend
- **Primary:** Bright Spring (75%)
- **Secondary:** Clear Winter (20%)  
- **Tertiary:** True Spring (5%)
- **Use case:** Test complex DNA blending with multiple influences

### 2. Soft Autumn (Pure Season)
- **Primary:** Soft Autumn (95%)
- **Use case:** Test pure season classification without blending

### 3. Deep Winter (Complex)
- **Primary:** Deep Winter (60%)
- **Secondary:** Dark Autumn (30%)
- **Tertiary:** True Winter (10%)
- **Use case:** Test complex three-season DNA blend

## Customizing Mock Data

### Adding New Mock Scenarios

1. **In `MockPersonalizedSeasonDataFactory.swift`:**

```swift
static func myNewScenario() -> PersonalizedSeasonData {
    return createMockData(
        season: "Light Summer",
        seasonDNA: SeasonDNA(
            primary: SeasonWeight(season: "Light Summer", weight: 0.80),
            secondary: SeasonWeight(season: "Light Spring", weight: 0.20),
            explanation: "Your custom explanation here...",
            classificationConfidence: 0.85
        ),
        emphasizedColors: ["#FF6B35", "#4ECDC4", "#45B7D1"],
        colorsToAvoid: ["#8B4513", "#2F4F4F"]
    )
}
```

2. **Add to debug menu in `DebugPersonalizedSeasonHelper.swift`:**

```swift
alert.addAction(UIAlertAction(title: "My New Scenario", style: .default) { _ in
    presentMockPersonalizedView(
        mockData: MockPersonalizedSeasonDataFactory.myNewScenario(),
        from: viewController
    )
})
```

### Customizing Colors and Content

**Season Colors:** Modify `getSeasonColors()` in `DebugPersonalizedSeasonHelper.swift`

**Content:** Update the helper methods in `MockPersonalizedSeasonDataFactory.swift`:
- `getCharacteristics(for:)`
- `getOverview(for:)`
- `createColorRecommendations(for:)`
- `createStylingAdvice(for:)`

## Testing Different Features

### DNA Ring Chart
- Test with different season blends
- Verify primary/secondary/tertiary visualization
- Check confidence indicators

### Enhanced Color Data
- Test with and without enhanced color data
- Verify color grid layouts
- Test color avoidance display

### Module Navigation
- Test all four modules (Characteristics, Colors, Styling, Makeup)
- Verify navigation animations
- Check content display

### Responsive Design
- Test on different device sizes
- Verify scroll behavior
- Check color contrast in different modes

## Best Practices

1. **Use Specific Scenarios:** Create targeted mock data for specific features you're testing
2. **Test Edge Cases:** Create mock data with minimal/maximum values
3. **Color Accessibility:** Test with high contrast mode enabled
4. **Performance:** Use mock data to test with many colors/recommendations
5. **Localization:** Create mock data with longer text for layout testing

## File Structure

```
ImageSegmenter/
├── Utils/
│   ├── MockPersonalizedSeasonDataFactory.swift  # Mock data creation
│   └── DebugPersonalizedSeasonHelper.swift       # Debug UI helpers
├── ViewContoller/Extensions/
│   └── RefactoredCameraViewController+Debug.swift # Debug button integration
└── Knowledge/
    └── MockPersonalizedSeasonGuide.md            # This guide
```

## Troubleshooting

### Common Issues

1. **Colors not displaying:** Check hex color format (use Color+Extensions.swift)
2. **Layout issues:** Test with different text lengths in mock data
3. **Navigation problems:** Verify all required properties are set in mock data
4. **Memory issues:** Use `#if DEBUG` to exclude mock code from release builds

### Debug Tips

- Use SwiftUI previews for rapid iteration
- Add print statements in view model methods
- Test with different confidence levels
- Verify DNA blend calculations
- Check color contrast ratios

## Performance Considerations

- Mock data is only included in debug builds (`#if DEBUG`)
- Mock factory methods are lightweight and fast
- No network calls or heavy computations
- Safe to use during development and testing 
