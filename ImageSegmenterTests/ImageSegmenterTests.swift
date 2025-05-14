//
//  ImageSegmenterTests.swift
//  ImageSegmenterTests
//
//  Created by MBA0077 on 12/5/23.
//

import XCTest
@testable import ImageSegmenter

final class ImageSegmenterTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFrameworkAvailable() throws {
        // This test verifies that the framework is available
        let testClass = XCTestCase.self
        XCTAssertNotNil(testClass, "XCTest framework should be available")
    }

    func testImageSegmenterAvailable() throws {
        // This test verifies that the main app module is available
        let classifier = SeasonClassifier()
        XCTAssertNotNil(classifier, "SeasonClassifier should be available")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}
