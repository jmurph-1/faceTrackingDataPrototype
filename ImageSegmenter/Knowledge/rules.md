# Rules

## Swift Coding Standards
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

## Rule for Adding New Files to the Project
When creating new files for the project, follow these steps to ensure they're properly included in Xcode:
1. **Create the file in the appropriate directory** in the project structure
1. **Add the file to the Xcode project**:
   * Open the Xcode project file (project.pbxproj) in a text editor
   * Add an entry in the PBXFileReference section with appropriate file type
   * Add a corresponding entry in the PBXBuildFile section
   * Add the file to the appropriate PBXGroup section
   * For source files (.swift, .metal), add the file to the PBXSourcesBuildPhase section
   * For resource files (.md, .tflite, etc.), add the file to the PBXResourcesBuildPhase section
