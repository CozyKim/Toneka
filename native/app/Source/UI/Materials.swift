//
//  Materials.swift
//  Toneka
//

import Cocoa

/// Whether the system material can be a glass effect right now.
///
/// Reduce Transparency asks for backgrounds to obscure what is behind them,
/// which is the opposite of what glass does, so it forces the fallback.
enum Materials {
  static var reduceTransparency: Bool {
    return NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
  }

  /// A view that renders the system material, sized to `bounds` and resizing
  /// with its superview. `content` is placed inside it.
  ///
  /// The glass variant is a Bool rather than an NSGlassEffectView.Style
  /// because that type is macOS 26 only and cannot appear in the signature of
  /// a function this deployment target has to compile.
  ///
  /// - Parameter preferClearGlass: Clear rather than Regular where glass is
  ///   available. Only VolumeHUD asks for this; per the design notes new
  ///   surfaces use Regular.
  /// - Parameter fallbackMaterial: NSVisualEffectView material otherwise.
  static func backdrop (
    bounds: NSRect,
    content: NSView,
    cornerRadius: CGFloat,
    preferClearGlass: Bool,
    fallbackMaterial: NSVisualEffectView.Material
  ) -> NSView {
    if #available(macOS 26.0, *), !reduceTransparency {
      // NSGlassEffectView only guarantees placement for its contentView, and
      // setting it is also what lets AppKit apply the legibility treatments.
      let glass = NSGlassEffectView(frame: bounds)
      glass.autoresizingMask = [.width, .height]
      glass.cornerRadius = cornerRadius
      glass.style = preferClearGlass ? .clear : .regular
      glass.contentView = content
      return glass
    }

    let blur = NSVisualEffectView(frame: bounds)
    blur.material = reduceTransparency ? .windowBackground : fallbackMaterial
    blur.blendingMode = .behindWindow
    blur.state = .active
    blur.wantsLayer = true
    blur.layer?.cornerRadius = cornerRadius
    blur.layer?.masksToBounds = true
    blur.autoresizingMask = [.width, .height]
    blur.addSubview(content)
    return blur
  }
}
