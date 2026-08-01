//
//  UI.swift
//  eqMac
//
//  Created by Roman Kisil on 24/12/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import ReSwift
import Cocoa
import EmitterKit
import SwiftyUserDefaults
import WebKit
import SwiftHTTP
import Shared

enum UIMode: String, Codable {
  case window = "window"
  case popover = "popover"
}

extension UIMode {
  static let allValues = [
    window.rawValue,
    popover.rawValue
  ]
}

class UI: StoreSubscriber {
  static var state: UIState {
    return Application.store.state.ui
  }

  static var minHeight: Double {
    return state.minHeight * scale
  }
  
  static var minWidth: Double {
    return state.minWidth * scale
  }
  
  static var maxHeight: Double {
    var maxHeight = (state.maxHeight ?? 4000) * scale
    if (maxHeight < minHeight) {
      maxHeight = minHeight
    }
    return maxHeight
  }
  
  static var maxWidth: Double {
    var maxWidth = (state.maxWidth ?? 4000) * scale
    if (maxWidth < minWidth) {
      maxWidth = minWidth
    }
    return maxWidth
  }

  static var height: Double {
    get {
      return window.height
    }
    set {
      window.height = newValue
    }
  }

  static var width: Double {
    get {
      return window.width
    }
    set {
      window.width = newValue
    }
  }

  static var scale: Double {
    return state.scale
  }

  static var minSize: NSSize {
    return NSSize(
      width: minWidth,
      height: minHeight
    )
  }

  static var maxSize: NSSize {
    if isResizable {
      return NSSize(
        width: maxWidth,
        height: maxHeight
      )
    } else {
      return minSize
    }
  }

  static var isResizable: Bool {
    return state.resizable
  }
  
  /// Unpacks the bundled UI on every launch, clearing the previous copy first
  /// so files that no longer exist in the bundle do not linger.
  ///
  /// Nothing is cached. The archive used to be kept in Application Support and
  /// the copy skipped when it was already there, which is how a downloaded UI
  /// was retained. With no remote UI left, that check only pinned the first
  /// build's interface for the life of an app version: a freshly built ui.zip
  /// was ignored until someone deleted the file by hand.
  static func unarchiveZip () {
    let bundleUIZipPath = Bundle.main.url(
      forResource: "ui", withExtension: "zip", subdirectory: "Embedded"
    )!

    try? FileManager.default.removeItem(at: localPath)
    try! unzip(bundleUIZipPath, into: localPath)
  }

  /// Extraction via ditto, which ships with macOS and overwrites in place.
  /// Avoids depending on a third-party zip library for the one thing we
  /// unpack -- the same kind of fork dependency that broke this build once.
  private static func unzip (_ archive: URL, into destination: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", archive.path, destination.path]

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw "Failed to extract \(archive.lastPathComponent): ditto exited \(process.terminationStatus)"
    }
  }
  
  static var localPath: URL {
    return Application.supportPath.appendingPathComponent("ui")
  }
  
  static let statusItem = StatusItem()

  static let storyboard = NSStoryboard(name: "Main", bundle: Bundle.main)

  static var windowController: NSWindowController = (
    storyboard.instantiateController(
      withIdentifier: "EQMWindowController"
    ) as! NSWindowController)
  static var window: Window = (windowController.window! as! Window)

  static var viewController = (
    storyboard.instantiateController(
      withIdentifier: "EQMViewController"
    ) as! ViewController)


  static var cachedIsShown: Bool = false
  static var isShownChanged = Event<Bool>()

  static var isShown: Bool {
    return window.isShown
  }
  
  static var mode: UIMode = .window {
    willSet {
      DispatchQueue.main.async {
        window.becomeFirstResponder()
        if (!duringInit) {
          show()
        }
      }
    }
  }

  static var alwaysOnTop = false {
    didSet {
      DispatchQueue.main.async {
        if alwaysOnTop {
          window.level = .floating
        } else {
          window.level = .normal
        }
      }
    }
  }
  
  static var canHide: Bool {
    get {
      return window.canHide
    }
    set {
      window.canHide = newValue
    }
  }
  
  static func toggle () {
    DispatchQueue.main.async {
      if isShown {
        close()
      } else {
        show()
      }
    }
  }
  
  static func show () {
    DispatchQueue.main.async {
      if mode == .popover {
        // If mode is Popover move the window to where the Popover would be
        if let frame = statusItem.item.button?.window?.frame {
          var point = frame.origin
          point.x = point.x - window.frame.width / 2 + frame.width / 2
          point.y -= 10
          window.setFrameOrigin(point)
        }
      }

      window.show()
      NSApp.activate(ignoringOtherApps: true)
    }
  }
  
  static func close () {
    DispatchQueue.main.async {
      window.close()
      NSApp.hide(self)
    }
  }

  static func hide () {
    DispatchQueue.main.async {
      if mode == .popover {
        close()
      } else {
        window.performMiniaturize(nil)
      }
    }
  }
  
  // Instance
  static var statusItemClickedListener: EventListener<Void>!
  static var bridge: Bridge!

  static var duringInit = true
  init (_ completion: @escaping () -> Void) {
    DispatchQueue.main.async {
      func setup () {
        ({
          UI.mode = Application.store.state.ui.mode
          UI.alwaysOnTop = Application.store.state.ui.alwaysOnTop
          UI.width = Application.store.state.ui.width
          UI.height = Application.store.state.ui.height
          UI.statusItem.iconType = Application.store.state.ui.statusItemIconType
        })()

        UI.window.contentViewController = UI.viewController

        // Set window position to where it was last time, in case that position is not available anymore - reset.
        if var windowPosition = Application.store.state.ui.windowPosition {
          var withinBounds = false
          for screen in NSScreen.screens {
            if NSPointInRect(windowPosition, screen.frame) {
              withinBounds = true
              break
            }
          }
          if (!withinBounds) {
            if let mainScreen = NSScreen.screens.first {
              let screenSize = mainScreen.frame.size
              windowPosition.x = screenSize.width / 2 - CGFloat(UI.width / 2)
              windowPosition.y = screenSize.height / 2 - CGFloat(UI.height / 2)
            } else {
              windowPosition.x = 0
              windowPosition.y = 0
            }
          }
          UI.window.position = windowPosition
          Application.dispatchAction(UIAction.setWindowPosition(windowPosition))
        }

        UI.close()
        
        self.setupStateListener()
        UI.setupBridge()
        UI.setupListeners()
        UI.load()

        func checkIfVisible () {
          let shown = UI.isShown
          if (UI.cachedIsShown != shown) {
            UI.cachedIsShown = shown
            UI.isShownChanged.emit(shown)
          }
          Async.delay(1000) { checkIfVisible() }
        }

        checkIfVisible()
        completion()
        Async.delay(1000) {
          UI.duringInit = false
        }
      }

      if (!UI.viewController.isViewLoaded) {
        UI.viewController.loaded.once {
          setup()
        }
        let _ = UI.viewController.view
      } else {
        setup()
      }


    }

  }
  
  static func reload () {
    viewController.webView.reload()
  }
  
  static func setupBridge () {
    bridge = Bridge(webView: viewController.webView)
  }
  
  // MARK: - State
  public typealias StoreSubscriberStateType = UIState
  
  private func setupStateListener () {
    Application.store.subscribe(self) { subscription in
      subscription.select { state in state.ui }
    }
  }
  
  func newState(state: UIState) {
    DispatchQueue.main.async {
      if (state.mode != UI.mode) {
        UI.mode = state.mode
      }
      if (state.alwaysOnTop != UI.alwaysOnTop) {
        UI.alwaysOnTop = state.alwaysOnTop
      }
      if (state.statusItemIconType != UI.statusItem.iconType) {
        UI.statusItem.iconType = state.statusItemIconType
      }

      if (state.height != UI.height && state.fromUI) {
        UI.height = state.height
      }

      if (state.width != UI.width && state.fromUI) {
        UI.width = state.width
      }

      UI.checkFixWindowSize()

    }
  }

  private static func checkFixWindowSize () {
    if (UI.height < Double(UI.minSize.height)) {
      UI.height = Double(UI.minSize.height)
    }

    if (UI.height > Double(UI.maxSize.height)) {
      UI.height = Double(UI.maxSize.height)
    }

    if (UI.width < Double(UI.minSize.width)) {
      UI.width = Double(UI.minSize.width)
    }

    if (UI.width > Double(UI.maxSize.width)) {
      UI.width = Double(UI.maxSize.width)
    }
  }
  
  private static func setupListeners () {
    statusItemClickedListener = statusItem.clicked.on {_ in
      toggle()
    }
  }
  
  static var hasLoaded = false
  static var loaded = Event<Void>()
  
  static func whenLoaded (_ completion: @escaping () -> Void) {
    if hasLoaded { return completion() }
    loaded.once {
      completion()
    }
  }
  
  private static func load () {
    hasLoaded = false

    func startUILoad (_ url: URL) {
      DispatchQueue.main.async {
        viewController.load(url)
      }
    }

    func loadBundled () {
      Console.log("Loading bundled UI")
      unarchiveZip()
      startUILoad(BundleSchemeHandler.url(forPath: "index.html"))
    }

    #if DEBUG
    devServerIsReachable { reachable in
      if reachable {
        Console.log("Loading UI from \(Constants.DEV_UI_URL)")
        startUILoad(Constants.DEV_UI_URL)
      } else {
        loadBundled()
      }
    }
    #else
    loadBundled()
    #endif
  }

  #if DEBUG
  /// One request against the dev server with a short deadline, so launch is not
  /// held up when nothing is listening there.
  private static func devServerIsReachable (_ completion: @escaping (Bool) -> Void) {
    var settled = false
    func settle (_ reachable: Bool) {
      if settled { return }
      settled = true
      completion(reachable)
    }

    HTTP.GET(Constants.DEV_UI_URL.absoluteString) { response in
      settle(response.error == nil)
    }

    Async.delay(1000) { settle(false) }
  }
  #endif

  deinit {
    Application.store.unsubscribe(self)
  }
}
