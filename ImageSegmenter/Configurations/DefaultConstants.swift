// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import UIKit
import MediaPipeTasksVision

// MARK: Define default constants
struct DefaultConstants {
  static let model: Model = .multiClassSegmentation
  static let delegate: Delegate = .CPU
}

// MARK: Model
enum Model: Int, CaseIterable {
    
    case multiClassSegmentation = 0
    // Face landmark detection is now handled by a separate toggle
    // and has been removed from the model selection dropdown

  var name: String {
    switch self {
    case .multiClassSegmentation:
      return "Multi-class segmentation"
    }
  }

  var modelPath: String? {
    switch self {
    case .multiClassSegmentation:
      return Bundle.main.path(
      forResource: "selfie_multiclass_256x256", ofType: "tflite")
    }
  }

  init?(name: String) {
    switch name {
    case "Multi-class segmentation":
      self.init(rawValue: 0)
    default:
      return nil
    }
  }
}
