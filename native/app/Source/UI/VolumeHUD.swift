//
//  VolumeHUD.swift
//  Toneka
//
//  On-screen volume feedback for the cases macOS does not cover.
//
//  The system HUD only appears when CoreAudio changes a hardware volume
//  control. Devices without one (HDMI and DisplayPort displays) therefore get
//  no feedback at all, and even on devices that have one the system stops at
//  100% and cannot show Toneka's boost range.
//

import Cocoa

final class VolumeHUD {
  private let window: NSWindow
  private let icon: NSImageView
  private let bar: VolumeBar
  private var dismissal: DispatchWorkItem?

  private static let size = NSSize(width: 232, height: 56)
  private static let visibleFor: TimeInterval = 1.2
  private static let fadeFor: TimeInterval = 0.35

  init () {
    window = NSWindow(
      contentRect: NSRect(origin: .zero, size: VolumeHUD.size),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .clear
    window.level = .statusBar
    window.ignoresMouseEvents = true
    window.hasShadow = true
    // Stays put when the user switches Spaces, like the system HUD.
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

    icon = NSImageView(frame: NSRect(x: 18, y: 16, width: 24, height: 24))
    icon.imageScaling = .scaleProportionallyUpOrDown
    // Semantic rather than a fixed white: inside a glass contentView AppKit
    // renders these vibrantly, so they stay legible as the glass picks up
    // whatever is behind the window. A hardcoded colour opts out of that.
    icon.contentTintColor = .labelColor

    bar = VolumeBar(frame: NSRect(x: 54, y: 24, width: 160, height: 8))
    bar.autoresizingMask = [.width]

    let bounds = NSRect(origin: .zero, size: VolumeHUD.size)
    let content = NSView(frame: bounds)
    content.autoresizingMask = [.width, .height]
    content.addSubview(icon)
    content.addSubview(bar)

    window.contentView = Materials.backdrop(
      bounds: bounds,
      content: content,
      cornerRadius: 14,
      preferClearGlass: true,
      fallbackMaterial: .hudWindow
    )
  }

  /// - Parameters:
  ///   - gain: 0...1 is normal range, above 1 is Toneka's boost.
  func show (gain: Double, muted: Bool) {
    Console.log("HUD show requested gain=\(gain) muted=\(muted)")
    DispatchQueue.main.async {
      self.icon.image = VolumeHUD.symbol(gain: gain, muted: muted)
      self.bar.gain = muted ? 0 : gain
      self.position()

      self.dismissal?.cancel()
      self.window.animator().alphaValue = 1
      self.window.orderFrontRegardless()
      Console.log("HUD ordered front", self.diagnostics())

      let dismissal = DispatchWorkItem { [weak self] in self?.fadeOut() }
      self.dismissal = dismissal
      DispatchQueue.main.asyncAfter(deadline: .now() + VolumeHUD.visibleFor, execute: dismissal)

      // Sampled once the fade-in should be over. The animator steps alphaValue
      // over time rather than setting it up front, so an animation that never
      // ran shows up here as alpha still at 0 on an otherwise visible window.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self else { return }
        Console.log("HUD settled", self.diagnostics())
      }
    }
  }

  private func fadeOut () {
    Console.log("HUD fade-out start alpha=\(window.alphaValue)")
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = VolumeHUD.fadeFor
      window.animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      guard let self = self else { return }
      // A show() during the fade would have raised alpha again; don't hide it.
      let hide = self.window.alphaValue == 0
      Console.log("HUD fade-out done alpha=\(self.window.alphaValue) orderOut=\(hide)")
      if hide { self.window.orderOut(nil) }
    })
  }

  /// Bottom centre of the screen holding the window that keyboard events go
  /// to, which is where macOS puts its own HUD. The mouse pointer is not a
  /// stand-in for that: the volume keys are keyboard input, so a pointer left
  /// parked on a second display would drag the HUD off the display the user is
  /// actually typing on.
  private func position () {
    guard let frame = NSScreen.main?.frame else {
      Console.log("HUD position skipped: NSScreen.main is nil, screens=\(VolumeHUD.describe(NSScreen.screens))")
      return
    }

    window.setFrameOrigin(NSPoint(
      x: frame.midX - VolumeHUD.size.width / 2,
      y: frame.minY + 140
    ))
  }

  /// Everything that decides whether the window is actually on screen, on
  /// one line so the log reads as a sequence of states.
  private func diagnostics () -> String {
    let content = window.contentView.map {
      "\(type(of: $0)) hidden=\($0.isHidden) frame=\(NSStringFromRect($0.frame))"
    } ?? "nil"
    return "visible=\(window.isVisible) alpha=\(window.alphaValue)"
      + " frame=\(NSStringFromRect(window.frame))"
      + " screen=\(window.screen?.localizedName ?? "none")"
      + " occlusionVisible=\(window.occlusionState.contains(.visible))"
      + " activeSpace=\(window.isOnActiveSpace) number=\(window.windowNumber)"
      + " appHidden=\(NSApp.isHidden) appActive=\(NSApp.isActive)"
      + " content=[\(content)]"
      + " main=\(NSScreen.main?.localizedName ?? "nil")"
      + " screens=\(VolumeHUD.describe(NSScreen.screens))"
  }

  private static func describe (_ screens: [NSScreen]) -> String {
    return "[" + screens.map { "\($0.localizedName)=\(NSStringFromRect($0.frame))" }.joined(separator: ", ") + "]"
  }

  private static func symbol (gain: Double, muted: Bool) -> NSImage? {
    let name: String
    if muted || gain <= 0 {
      name = "speaker.slash.fill"
    } else if gain > 1 {
      name = "speaker.wave.3.fill"
    } else if gain < 0.34 {
      name = "speaker.wave.1.fill"
    } else if gain < 0.67 {
      name = "speaker.wave.2.fill"
    } else {
      name = "speaker.wave.3.fill"
    }
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)
  }
}

/// Volume track. The stretch past 100% is drawn in a different colour so the
/// boost range reads as distinct rather than as a longer normal bar.
private final class VolumeBar: NSView {
  var gain: Double = 0 {
    didSet { needsDisplay = true }
  }

  override func draw (_ dirtyRect: NSRect) {
    let radius = bounds.height / 2

    // Semantic colours throughout: they render vibrantly inside the glass and
    // adapt to the backdrop, which fixed white and opaque greys cannot do.
    NSColor.quaternaryLabelColor.setFill()
    NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

    guard gain > 0 else { return }

    // 0...1 fills the whole track; 1...2 is drawn over it in the boost colour.
    let normal = min(gain, 1.0)
    let normalWidth = bounds.width * CGFloat(normal)
    if normalWidth > 0 {
      NSColor.labelColor.setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: normalWidth, height: bounds.height),
        xRadius: radius, yRadius: radius
      ).fill()
    }

    if gain > 1 {
      let boost = min((gain - 1.0) / 1.0, 1.0)
      let boostWidth = bounds.width * CGFloat(boost)
      NSColor.systemOrange.setFill()
      NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: boostWidth, height: bounds.height),
        xRadius: radius, yRadius: radius
      ).fill()
    }
  }
}
