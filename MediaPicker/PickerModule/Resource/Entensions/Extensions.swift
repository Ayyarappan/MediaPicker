//
//  Extensions.swift
//  MediaPicker
//
//  Created by Ayyarappan K on 03/01/25.
//

import Foundation
import UIKit
import Photos

extension UIView {
    func rotate(degrees: CGFloat) {
        let degreesToRadians: (CGFloat) -> CGFloat = { (degrees: CGFloat) in
            return degrees / 180.0 * CGFloat.pi
        }
        self.transform =  CGAffineTransform(rotationAngle: degreesToRadians(degrees))
    }
    
    func addBlurEffect(blurAnimator: UIViewPropertyAnimator = UIViewPropertyAnimator(), blurEffectView: UIVisualEffectView = UIVisualEffectView(), fraction: CGFloat? = 0.7) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            blurEffectView.frame = UIScreen.main.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurEffectView.isUserInteractionEnabled = false
            self.addSubview(blurEffectView)
            
            blurAnimator.addAnimations {
                blurEffectView.effect = UIBlurEffect(style: .regular)
            }
            
            if blurAnimator.state == .inactive {
                blurAnimator.startAnimation()
                blurAnimator.pauseAnimation()
                blurAnimator.fractionComplete = fraction ?? 0.7
                blurAnimator.pausesOnCompletion = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    blurAnimator.pauseAnimation()
                    blurAnimator.stopAnimation(true)
                    blurAnimator.finishAnimation(at: .current)
                }
            }
        }
    }
    
    func removeBlur() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            for subview in self.subviews {
                if subview is UIVisualEffectView {
                    subview.removeFromSuperview()
                }
            }
        }
    }
    
    func stopInteraction(duration:Double = 0.5) {
        self.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.isUserInteractionEnabled = true
        }
    }
    
}


extension UIViewController {
    // For haptic feedback
    func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: style)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()
    }
    
    // alert controller, style => actionSheet
    func showAlert(with message:String, autoDismissTime: DispatchTime? = .now() + 2, completion: @escaping () -> ()) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: .actionSheet)
        self.present(alert, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: autoDismissTime ?? .now() + 2) {
                alert.dismiss(animated: true) {
                    completion()
                }
            }
        }
    }
}
