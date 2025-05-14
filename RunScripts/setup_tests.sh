#!/bin/bash

# This script sets up the proper testing environment

# Create directories if they don't exist
mkdir -p ImageSegmenterTests

# Copy any necessary files from the main app to the test directory
cp -n ImageSegmenter/Tests/*Tests.swift ImageSegmenterTests/

# Ensure proper imports and module references
find ImageSegmenterTests -name "*.swift" -type f -exec sed -i '' -e 's/@testable import ColorAnalysisApp/@testable import ImageSegmenter/g' {} \;

# Add the xcconfig file to the test target if it doesn't exist
if [ ! -f "ImageSegmenterTests/build.xcconfig" ]; then
  echo "// Test target configuration
FRAMEWORK_SEARCH_PATHS = \$(inherited) \$(PLATFORM_DIR)/Developer/Library/Frameworks
ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES
LD_RUNPATH_SEARCH_PATHS = \$(inherited) @executable_path/Frameworks @loader_path/Frameworks" > ImageSegmenterTests/build.xcconfig
fi

echo "Test environment setup complete!" 