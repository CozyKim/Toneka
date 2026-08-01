//
//  AppDelegate.swift
//  eqMac
//
//  Created by Roman Kisil on 27/11/2017.
//  Copyright © 2017 Roman Kisil. All rights reserved.
//

import Cocoa
import SwiftyJSON
import ServiceManagement
import Sparkle
import EmitterKit
import Shared

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {

  var updateProcessed = EmitterKit.Event<Void>()

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    for window in NSApplication.shared.windows {
      window.close()
    }

    // Sparkle 2 takes its delegate at construction time, so the controller has
    // to exist before anything touches Application.updater.
    Application.updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: self,
      userDriverDelegate: nil
    )

    updateProcessed.once { _ in
      Application.start()
    }

    if (Application.store.state.settings.doAutoCheckUpdates) {
      // Launch is gated on the update check finishing, so guarantee it ends:
      // fire once whichever comes first, the check or the timeout.
      var settled = false
      func settle () {
        if settled { return }
        settled = true
        self.updateProcessed.emit()
      }
      updateCycleFinished = settle

      Networking.checkConnected { connected in
        if (connected) {
          Application.updater.checkForUpdatesInBackground()
        } else {
          settle()
        }
      }

      Async.delay(5000) { settle() }
    } else {
      self.updateProcessed.emit()
    }

    NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(didWakeUp(event:)),
        name: NSWorkspace.didWakeNotification, object: nil)

    NSWorkspace.shared.notificationCenter.addObserver(
        self, selector: #selector(willSleep(event:)),
        name: NSWorkspace.willSleepNotification, object: nil)
  }
  
  func applicationWillTerminate(_ aNotification: Notification) {
    Application.handleTermination()
  }
  
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    UI.show()
    return true
  }
  
  func applicationWillBecomeActive(_ notification: Notification) {
    
  }
  
  func applicationDidBecomeActive(_ notification: Notification) {
//    if (UI.hasLoaded) {
//      UI.show()
//    }
  }

  func applicationDidResignActive(_ notification: Notification) {
    if UI.mode == .popover {
      UI.close()
    }
  }
  
  // MARK: - SPUUpdaterDelegate

  /// Set while launch is waiting on the update check. Sparkle 2 reports the end
  /// of a check through a single callback, so the eight separate Sparkle 1
  /// delegate methods this used to need collapse into it.
  private var updateCycleFinished: (() -> Void)?

  func updater (
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: Error?
  ) {
    updateCycleFinished?()
  }

  /// Sparkle 2 prefers the feed to come from the delegate rather than being
  /// written into user defaults, which also keeps the beta toggle honest -- it
  /// is read fresh on every check.
  func feedURLString (for updater: SPUUpdater) -> String? {
    return Settings.updatesFeedUrl?.absoluteString
  }

  @objc func willSleep(event: NSNotification) {
    Application.handleSleep()
  }

  @objc func didWakeUp(event: NSNotification) {
    Application.handleWakeUp()
  }
}


