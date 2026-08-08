//
//  ViewController.swift
//  Toneka
//
//  Created by Roman Kisil on 10/12/2017.
//  Copyright © 2017 Roman Kisil. All rights reserved.
//

import Cocoa
import WebKit
import EmitterKit
import Shared

class ViewController: NSViewController, WKNavigationDelegate {
  // MARK: - Properties
  @IBOutlet var parentView: View!
  @IBOutlet var webView: WKWebView!
  @IBOutlet var draggableView: DraggableView!
  @IBOutlet var loadingView: NSView!
  @IBOutlet var loadingSpinner: NSProgressIndicator!
  let loaded = Event<Void>()

  var height: Double {
    get {
      return Double(webView.frame.size.height)
    }
    set {
      let newHeight = CGFloat(newValue)
      let newSize = NSSize(width: webView.frame.size.width, height: newHeight)
      self.view.setFrameSize(newSize)
    }
  }
  
  var width: Double {
    get {
      return Double(webView.frame.size.width)
    }
    set {
      let newWidth = CGFloat(newValue)
      let newSize = NSSize(width: newWidth, height: CGFloat(height))
      self.view.setFrameSize(newSize)
    }
  }

  // MARK: - Initialization
  override func viewDidLoad () {
    super.viewDidLoad()
    useSchemeAwareWebView()
    installBackdrop()
    loadingSpinner.startAnimation(nil)
    loaded.emit()
  }

  /// Swaps the storyboard's web view for one whose configuration carries the
  /// bundle scheme handler. A handler can only be registered before the web
  /// view exists, and the storyboard builds its own.
  private func useSchemeAwareWebView () {
    let configuration = WKWebViewConfiguration()
    configuration.setURLSchemeHandler(
      BundleSchemeHandler(root: UI.localPath),
      forURLScheme: BundleSchemeHandler.scheme
    )
    // Mirrors what the storyboard set on the view being replaced.
    configuration.mediaTypesRequiringUserActionForPlayback = []
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

    let replacement = WKWebView(frame: webView.frame, configuration: configuration)
    replacement.autoresizingMask = webView.autoresizingMask
    replacement.allowsLinkPreview = false
    replacement.wantsLayer = true

    webView.superview?.replaceSubview(webView, with: replacement)
    webView = replacement
  }

  /// Moves the storyboard's subviews inside a material view so the window can
  /// show system material behind the web content.
  private func installBackdrop () {
    // drawsBackground is not exposed on macOS WKWebView, but the underlying
    // setting is what makes the web content composite over what is behind it.
    webView.setValue(false, forKey: "drawsBackground")

    let content = NSView(frame: view.bounds)
    content.autoresizingMask = [.width, .height]
    for subview in view.subviews {
      subview.removeFromSuperview()
      content.addSubview(subview)
    }

    let backdrop = Materials.backdrop(
      bounds: view.bounds,
      content: content,
      cornerRadius: 0,
      preferClearGlass: false,
      fallbackMaterial: .sidebar
    )
    view.addSubview(backdrop)
  }

  func load (_ url: URL) {
    if self.webView.isLoading {
      self.webView.stopLoading()
    }

    self.webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData))

    
    Async.delay(1000) {
      self.loadingView.isHidden = true
      self.loadingSpinner.stopAnimation(nil)
    }

    if Constants.DEBUG {
      Console.log("Enabling DevTools")
      self.webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
    }
  }
  
  // MARK: - Listeners
  override func viewWillAppear() {
    super.viewWillAppear()
  }
  
  func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    let cred = URLCredential(trust: challenge.protectionSpace.serverTrust!)
    completionHandler(.useCredential, cred)
  }
  
}

class View: NSView {
  override var acceptsFirstResponder: Bool { true }
  override func keyDown(with event: NSEvent) {
    // This is an override to disable OS sound effects (beeps and boops) when pressing keys inside the view
  }
  
}
