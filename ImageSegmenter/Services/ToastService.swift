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

/// Service for displaying toast-style error messages
class ToastService {
    // MARK: - Properties
    private let containerView: UIView
    private let toastLabel: UILabel
    private var toastTimer: Timer?
    private var messageQueue: [ToastMessage] = []
    private var isShowingMessage = false
    
    // Default position from bottom
    private let defaultBottomOffset: CGFloat = 140
    
    // MARK: - Initialization
    
    /// Initialize with the container view where toasts will be displayed
    /// - Parameter containerView: UIView where toast messages will be shown
    init(containerView: UIView) {
        self.containerView = containerView
        
        // Create the toast label
        self.toastLabel = UILabel()
        self.toastLabel.translatesAutoresizingMaskIntoConstraints = false
        self.toastLabel.textColor = .white
        self.toastLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        self.toastLabel.textAlignment = .center
        self.toastLabel.layer.cornerRadius = 10
        self.toastLabel.clipsToBounds = true
        self.toastLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        self.toastLabel.numberOfLines = 0
        self.toastLabel.alpha = 0 // Initially hidden
        
        // Add to container view
        containerView.addSubview(self.toastLabel)
        
        // Position the toast
        NSLayoutConstraint.activate([
            self.toastLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            self.toastLabel.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -defaultBottomOffset),
            self.toastLabel.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor, constant: -40)
        ])
    }
    
    // MARK: - Public Methods
    
    /// Show a toast message
    /// - Parameters:
    ///   - message: Message to display
    ///   - duration: How long to show the message (default: 3 seconds)
    ///   - type: Type of message (error, warning, or info)
    func showToast(_ message: String, duration: TimeInterval = 3.0, type: ToastType = .error) {
        // Create a toast message object
        let toastMessage = ToastMessage(text: message, duration: duration, type: type)
        
        // Add to queue
        messageQueue.append(toastMessage)
        
        // Display if not already showing a message
        if !isShowingMessage {
            displayNextMessage()
        }
    }
    
    /// Clear any currently displayed toast messages
    func clearToast() {
        // Cancel current timer
        toastTimer?.invalidate()
        toastTimer = nil
        
        // Clear queue
        messageQueue.removeAll()
        
        // Animate out
        UIView.animate(withDuration: 0.3) {
            self.toastLabel.alpha = 0.0
        } completion: { _ in
            self.isShowingMessage = false
        }
    }
    
    // MARK: - Private Methods
    
    /// Display the next message in queue
    private func displayNextMessage() {
        // Ensure we're on the main thread
        DispatchQueue.main.async {
            // If queue is empty or already showing, return
            guard !self.messageQueue.isEmpty, !self.isShowingMessage else {
                return
            }
            
            // Get next message
            let message = self.messageQueue.removeFirst()
            self.isShowingMessage = true
            
            // Update toast style based on message type
            switch message.type {
            case .error:
                self.toastLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
            case .warning:
                self.toastLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
            case .info:
                self.toastLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            }
            
            // Update message and show
            self.toastLabel.text = message.text
            
            // Animate in
            UIView.animate(withDuration: 0.3) {
                self.toastLabel.alpha = 1.0
            }
            
            // Set timer to hide
            self.toastTimer = Timer.scheduledTimer(withTimeInterval: message.duration, repeats: false) { [weak self] _ in
                // Ensure animation runs on main thread
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3) {
                        self?.toastLabel.alpha = 0.0
                    } completion: { _ in
                        self?.isShowingMessage = false
                        // Check if there are more messages to display
                        self?.displayNextMessage()
                    }
                }
            }
        }
    }
}

// MARK: - ToastMessage
struct ToastMessage {
    let text: String
    let duration: TimeInterval
    let type: ToastType
}

// MARK: - ToastType
enum ToastType {
    case error
    case warning
    case info
} 