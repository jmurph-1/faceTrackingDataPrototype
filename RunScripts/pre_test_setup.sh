#!/bin/bash

# This script runs before the test phase to ensure proper test environment

# Make sure XCTest framework is in the search path
export FRAMEWORK_SEARCH_PATHS="${FRAMEWORK_SEARCH_PATHS} ${PLATFORM_DIR}/Developer/Library/Frameworks"

# Ensure proper module name is used
find "${SRCROOT}/ImageSegmenterTests" -name "*.swift" -type f -exec sed -i '' -e 's/@testable import ColorAnalysisApp/@testable import ImageSegmenter/g' {} \;

echo "Pre-test setup complete!" 