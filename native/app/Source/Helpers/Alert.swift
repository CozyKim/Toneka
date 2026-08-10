//
//  Alert.swift
//  Toneka
//
//  Created by Roman Kisil on 30/10/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import AppKit

class Alert {
  static func info (title: String, message: String) {
    DispatchQueue.main.async {
      let alert = getAlert(title, message)
      alert.addButton(withTitle: "Ok")
      alert.runModal()
    }
  }
  
  static func confirm (
    title: String,
    message: String,
    okText: String = "Ok",
    cancelText: String = "Cancel",
    callback: @escaping (Bool) -> Void
  ) {
    withButtons(title: title, message: message, buttons: [okText, cancelText]) { buttonPressed in
      let result = NSApplication.ModalResponse(buttonPressed) == .alertFirstButtonReturn
      callback(result)
    }
  }
  
  static func prompt (
    title: String,
    message: String,
    okText: String = "Save",
    cancelText: String = "Cancel",
    callback: @escaping (String?) -> Void
  ) {
    DispatchQueue.main.async {
      let alert = getAlert(title, message)
      alert.addButton(withTitle: okText)
      alert.addButton(withTitle: cancelText)
      let input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
      input.stringValue = ""
      alert.accessoryView = input
      if (alert.runModal() == .alertFirstButtonReturn) {
        input.validateEditing()
        callback(input.stringValue == "" ? nil : input.stringValue)
      }
      callback(nil)
    }
    
  }
  
  /// Driven as a modal session rather than `runModal`, which runs an event loop
  /// of its own and never yields the main queue. CoreAudio device notifications
  /// are handled there, so a blocking alert leaves the app deaf to output
  /// changes until someone dismisses it -- and the one alert Toneka raises
  /// reports a broken audio pipeline, so that is precisely when it has to keep
  /// listening.
  static func withButtons (
    title: String,
    message: String,
    buttons: [String],
    callback: @escaping (Int) -> Void
  ) {
    DispatchQueue.main.async {
      let alert = getAlert(title, message)
      for text in buttons {
        alert.addButton(withTitle: text)
      }

      // Sizing the window to its text and dropping the views it is not using --
      // the spare buttons, the suppression checkbox, the help button -- happens
      // as part of being displayed, which `runModal` does for you. Driving the
      // window ourselves reaches it before any of that: the message field keeps
      // its placeholder height of one line and the unused views stay on screen.
      alert.layout()

      let session = NSApp.beginModalSession(for: alert.window)

      func pump () {
        let response = NSApp.runModalSession(session)
        guard response == .continue else {
          NSApp.endModalSession(session)
          alert.window.orderOut(nil)
          callback(response.rawValue)
          return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1 / 60, execute: pump)
      }
      pump()
    }
  }
  
  static private func getAlert (_ title: String, _ message: String) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    return alert
  }
}
