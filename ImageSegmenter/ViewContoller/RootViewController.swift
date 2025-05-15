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

import UIKit

protocol InferenceResultDeliveryDelegate: AnyObject {
  func didPerformInference(result: ResultBundle?)
}

/** The view controller is responsible for presenting the camera feed */
class RootViewController: UIViewController {

  // MARK: Storyboards Connections
  @IBOutlet weak var tabBarContainerView: UIView!
  
  // MARK: Constants
  private struct Constants {
    static let cameraViewControllerStoryBoardId = "CAMERA_VIEW_CONTROLLER"
    static let storyBoardName = "Main"
  }

  // MARK: Controllers that manage functionality
  private var cameraViewController: CameraViewController?

  // MARK: View Handling Methods
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupCameraViewController()
    
    // Configure default settings
    // InferenceConfigurationManager.sharedInstance is already initialized with defaults
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  // MARK: Private Methods
  private func setupCameraViewController() {
    guard let viewController = UIStoryboard(
      name: Constants.storyBoardName, bundle: .main)
      .instantiateViewController(
        withIdentifier: Constants.cameraViewControllerStoryBoardId) as? CameraViewController else {
      return
    }

    viewController.inferenceResultDeliveryDelegate = self
    cameraViewController = viewController
    
    // Add camera view controller to container view
    addChild(viewController)
    viewController.view.translatesAutoresizingMaskIntoConstraints = false
    tabBarContainerView.addSubview(viewController.view)
    
    // Setup constraints
    NSLayoutConstraint.activate([
      viewController.view.leadingAnchor.constraint(equalTo: tabBarContainerView.leadingAnchor),
      viewController.view.trailingAnchor.constraint(equalTo: tabBarContainerView.trailingAnchor),
      viewController.view.topAnchor.constraint(equalTo: tabBarContainerView.topAnchor),
      viewController.view.bottomAnchor.constraint(equalTo: tabBarContainerView.bottomAnchor)
    ])
    
    viewController.didMove(toParent: self)
  }
}

// MARK: InferenceResultDeliveryDelegate Methods
extension RootViewController: InferenceResultDeliveryDelegate {
  func didPerformInference(result: ResultBundle?) {
    // We could log inference results or use them in other ways if needed
  }
}
