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
class AppDelegate: NSObject, NSApplicationDelegate, SUUpdaterDelegate {

  var updateProcessed = EmitterKit.Event<Void>()
  var willBeDownloadingUpdate = false
  
  func applicationDidFinishLaunching(_ aNotification: Notification) {
    for window in NSApplication.shared.windows {
      window.close()
    }

    Application.updater.delegate = self
    Application.updater.feedURL = Settings.updatesFeedUrl
    
    updateProcessed.once { _ in
      Application.start()
    }

    // Debug builds skip the update check entirely: Sparkle 1.x can leave the
    // callback pending against the live appcast, and start() is gated behind
    // it, so the app would never finish launching.
    if (!Constants.DEBUG && Application.store.state.settings.doAutoCheckUpdates) {
      var stillCheckingConnection = true
      Networking.checkConnected { connected in
        stillCheckingConnection = false
        if (connected) {
          Application.updater.checkForUpdatesInBackground()
        } else {
          self.updateProcessed.emit()
        }
      }

      Async.delay(2000) {
        if (stillCheckingConnection) {
          self.updateProcessed.emit()
        }
      }
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
  
  func updaterDidNotFindUpdate(_ updater: SUUpdater) {
    updateProcessed.emit()
  }
  
  func updater(_ updater: SUUpdater, userDidSkipThisVersion item: SUAppcastItem) {
    updateProcessed.emit()
  }
  
  func updater(_ updater: SUUpdater, didCancelInstallUpdateOnQuit item: SUAppcastItem) {
    updateProcessed.emit()
  }
  
  func updater(_ updater: SUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
    willBeDownloadingUpdate = true
  }
  
  func updater(_ updater: SUUpdater, didDismissUpdateAlertPermanently permanently: Bool, for item: SUAppcastItem) {
    Async.delay(500, completion: {
      if !self.willBeDownloadingUpdate {
        self.updateProcessed.emit()
      }
    })
  }
  
  func userDidCancelDownload(_ updater: SUUpdater) {
    updateProcessed.emit()
  }
  
  func updater(_ updater: SUUpdater, didAbortWithError error: Error) {
    updateProcessed.emit()
  }
  
  func updater(_ updater: SUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
    updateProcessed.emit()
  }

  @objc func willSleep(event: NSNotification) {
    Application.handleSleep()
  }

  @objc func didWakeUp(event: NSNotification) {
    Application.handleWakeUp()
  }
}


