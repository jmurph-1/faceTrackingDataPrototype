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
import SwiftUI
//import ImageSegmenter.Views

protocol InferenceResultDeliveryDelegate: AnyObject {
  func didPerformInference(result: ResultBundle?)
}

/** The view controller is responsible for presenting the camera feed */
class RootViewController: UIViewController {

  // MARK: Storyboards Connections
  @IBOutlet weak var tabBarContainerView: UIView!
  
  // MARK: Constants
  private struct Constants {
    static let refactoredCameraViewControllerStoryBoardId = "REFACTORED_CAMERA_VIEW_CONTROLLER" // Ensure this ID is set in your Storyboard for RefactoredCameraViewController
    static let storyBoardName = "Main"
  }

  // MARK: Controllers that manage functionality
  private var refactoredCameraViewController: RefactoredCameraViewController?
  private var landingPageViewController: UIHostingController<LandingPageView>?
  private var isShowingLandingPage = true

  // MARK: View Handling Methods
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Setup camera view controller but don't show it yet
    setupRefactoredCameraViewController()
    
    setupLandingPageViewController()
    
    // Configure default settings
    // InferenceConfigurationManager.sharedInstance is already initialized with defaults
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  // MARK: Private Methods
  private func setupRefactoredCameraViewController() {
    guard let viewController = UIStoryboard(
      name: Constants.storyBoardName, bundle: .main)
      .instantiateViewController(
        withIdentifier: Constants.refactoredCameraViewControllerStoryBoardId) as? RefactoredCameraViewController else {
      print("Error: Could not instantiate RefactoredCameraViewController from storyboard. Make sure the Storyboard ID is correct.")
      return
    }

    viewController.inferenceResultDeliveryDelegate = self 
    refactoredCameraViewController = viewController
    
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
  
  private func setupLandingPageViewController() {
    let landingPageView = LandingPageView(onAnalyzeButtonTapped: { [weak self] in
      self?.showCameraView()
    })
    
    let hostingController = UIHostingController(rootView: landingPageView)
    landingPageViewController = hostingController
    
    // Add landing page view controller to container view
    addChild(hostingController)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    tabBarContainerView.addSubview(hostingController.view)
    
    // Setup constraints
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: tabBarContainerView.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: tabBarContainerView.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: tabBarContainerView.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: tabBarContainerView.bottomAnchor)
    ])
    
    hostingController.didMove(toParent: self)
    
    refactoredCameraViewController?.view.isHidden = true
  }
  
  private func showCameraView() {
    refactoredCameraViewController?.shouldAutoStartAnalysis = true
    
    UIView.transition(with: tabBarContainerView, duration: 0.3, options: .transitionCrossDissolve) { [weak self] in
      self?.landingPageViewController?.view.isHidden = true
      self?.refactoredCameraViewController?.view.isHidden = false
      self?.isShowingLandingPage = false
    } completion: { [weak self] _ in
        print("RootVC: Transition to camera view completed. Calling prepareAndStartCameraIfNeeded.")
        self?.refactoredCameraViewController?.prepareAndStartCameraIfNeeded()
    }
  }
  
  private func showLandingPage() {
    UIView.transition(with: tabBarContainerView, duration: 0.3, options: .transitionCrossDissolve) { [weak self] in
      self?.landingPageViewController?.view.isHidden = false
      self?.refactoredCameraViewController?.view.isHidden = true
      self?.isShowingLandingPage = true
    } completion: { [weak self] _ in
        print("RootVC: Transition to landing page completed. Stopping camera.")
        self?.refactoredCameraViewController?.stopCameraProcessing()
    }
  }
}

// MARK: InferenceResultDeliveryDelegate Methods
extension RootViewController: InferenceResultDeliveryDelegate {
  func didPerformInference(result: ResultBundle?) {
    // We could log inference results or use them in other ways if needed
  }
}
