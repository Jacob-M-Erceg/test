//
//  AlertManager.swift
//  TodoPad
//
//  Created by John Lee on 2022-08-20.
//

import UIKit

// MARK: - Basic Alerts
class AlertManager {
    
    
    /// A helper funtion to show a basic alert with a title, an optional message and a "Dismiss" button.
    /// - Parameters:
    ///   - vc: The UIViewController that you wish to display the alert on.
    ///   - title: The title for the alert.
    ///   - message: A optional additional message for the alert.
    static func showBasicAlert(on vc: UIViewController, title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        DispatchQueue.main.async { vc.present(alert, animated: true) }
    }
    
    
    /// Shows an error saying you cant currently edit a task's type. Example: you cannot currently change a Repeating Task to a Persistent Task.
    static func showCannotEditTaskTypeErrorAlert(on vc: UIViewController, firstTaskType: String, secondTaskType: String) {
        self.showBasicAlert(on: vc, title: "Editing Error", message: "You cannot currently change a \(firstTaskType) Task to a \(secondTaskType) Task.")
    }
}