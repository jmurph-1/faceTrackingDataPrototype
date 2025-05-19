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

protocol InferenceResultDeliveryDelegate: AnyObject {
  func didPerformInference(result: ResultBundle?)
}

class RootViewController: UIViewController {

  // MARK: Storyboards Connections
  @IBOutlet weak var tabBarContainerView: UIView! // Ensure this is connected in Main.storyboard
  
  // MARK: Constants
  private struct Constants {
    static let refactoredCameraViewControllerStoryBoardId = "REFACTORED_CAMERA_VIEW_CONTROLLER"
    static let storyBoardName = "Main"
  }

  // MARK: Controllers that manage functionality
  private var refactoredCameraViewController: RefactoredCameraViewController?
  private var landingPageViewController: UIHostingController<LandingPageView>?
  private var isShowingLandingPage = true

  // MARK: View Handling Methods
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Ensure the outlet is connected
    if tabBarContainerView == nil {
        print("RootVC ERROR: tabBarContainerView outlet is NOT connected!")
        // Optionally, add a visual indicator like a red background to self.view
        // self.view.backgroundColor = .red
        return // Prevent further setup if outlet is missing
    }
    
    setupRefactoredCameraViewController()
    setupLandingPageViewController()
    // tabBarContainerView.backgroundColor = .cyan // Optional: for debugging layout
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
    self.refactoredCameraViewController = viewController
    
    addChild(viewController)
    viewController.view.translatesAutoresizingMaskIntoConstraints = false
    tabBarContainerView.addSubview(viewController.view)
    
    NSLayoutConstraint.activate([
      viewController.view.leadingAnchor.constraint(equalTo: tabBarContainerView.leadingAnchor),
      viewController.view.trailingAnchor.constraint(equalTo: tabBarContainerView.trailingAnchor),
      viewController.view.topAnchor.constraint(equalTo: tabBarContainerView.topAnchor),
      viewController.view.bottomAnchor.constraint(equalTo: tabBarContainerView.bottomAnchor)
    ])
    
    viewController.didMove(toParent: self)
  }
  
  private func setupLandingPageViewController() {
    let landingPageView = LandingPageView(
        onAnalyzeButtonTapped: { [weak self] in
            self?.showCameraView() // Re-enable showing camera view
        },
        onSubSeasonTapped: { [weak self] subSeasonName in
            self?.showDefaultSeasonView(for: subSeasonName)
        }
    )
    
    let hostingController = UIHostingController(rootView: landingPageView)
    self.landingPageViewController = hostingController
    
    addChild(hostingController)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    tabBarContainerView.addSubview(hostingController.view) // Add to tabBarContainerView
    
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: tabBarContainerView.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: tabBarContainerView.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: tabBarContainerView.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: tabBarContainerView.bottomAnchor)
    ])
    
    hostingController.didMove(toParent: self)
    
    // Ensure camera view is hidden AND behind the landing page initially
    if let cameraView = refactoredCameraViewController?.view {
        cameraView.isHidden = true
        tabBarContainerView.sendSubviewToBack(cameraView)
    }
  }

  private func showDefaultSeasonView(for seasonName: String) {
      print("RootVC: Transitioning to DefaultSeasonView for \(seasonName)")
      let theme = SeasonTheme.getTheme(for: seasonName)
      let defaultSeasonView = DefaultSeasonView( // Ensure this struct is named DefaultSeasonView if you use it
          seasonName: seasonName,
          primaryColor: theme.primaryColor,
          paletteWhite: theme.paletteWhite, 
          accentColor: theme.accentColor,
          accentColor2: theme.accentColor2, 
          backgroundColor: theme.backgroundColor,
          secondaryBackgroundColor: theme.secondaryBackgroundColor,
          textColor: theme.textColor,
          moduleColor: theme.moduleColor
      )
      
      let hostingController = UIHostingController(rootView: defaultSeasonView)
      hostingController.modalPresentationStyle = .fullScreen 
      
      // Ensure RootViewController itself can present
      if let rootVC = UIApplication.shared.windows.first?.rootViewController {
          var presenter = rootVC
          while let presented = presenter.presentedViewController {
              presenter = presented
          }
          presenter.present(hostingController, animated: true, completion: nil)
      } else {
          self.present(hostingController, animated: true, completion: nil)
      }
  }
  
  private func showCameraView() {
    guard let cameraVC = refactoredCameraViewController, let landingVC = landingPageViewController else {
        print("RootVC: Cannot show camera view, either cameraVC or landingVC is nil.")
        return
    }
    cameraVC.shouldAutoStartAnalysis = true
    
    UIView.transition(with: tabBarContainerView, duration: 0.3, options: .transitionCrossDissolve) {
      landingVC.view.isHidden = true
      cameraVC.view.isHidden = false
      self.isShowingLandingPage = false
    } completion: { _ in
        print("RootVC: Transition to camera view completed. Calling prepareAndStartCameraIfNeeded.")
        cameraVC.prepareAndStartCameraIfNeeded()
    }
  }
  
  func showLandingPage() { // Made this non-private in case it needs to be called from cameraVC
    guard let cameraVC = refactoredCameraViewController, let landingVC = landingPageViewController else {
        print("RootVC: Cannot show landing page, either cameraVC or landingVC is nil.")
        return
    }
    UIView.transition(with: tabBarContainerView, duration: 0.3, options: .transitionCrossDissolve) {
      landingVC.view.isHidden = false
      cameraVC.view.isHidden = true
      self.isShowingLandingPage = true
    } completion: { _ in
        print("RootVC: Transition to landing page completed. Stopping camera.")
        cameraVC.stopCameraProcessing()
    }
  }
}

// MARK: InferenceResultDeliveryDelegate Methods
extension RootViewController: InferenceResultDeliveryDelegate {
  func didPerformInference(result: ResultBundle?) {
    // We could log inference results or use them in other ways if needed
  }
}
