//
//  SpectrumDataBus.swift
//  eqMac
//

import Foundation
import EmitterKit
import SwiftyJSON

class SpectrumDataBus: DataBus {
  /// The analyser belongs to the route because the route is the only thing that
  /// ever asks for it, and its lifetime is exactly the route's.
  private let analyser = SpectrumAnalyser()
  private var volumesListener: EventListener<Spectrum>?

  required init (route: String, bridge: Bridge) {
    super.init(route: route, bridge: bridge)

    self.on(.GET, "/enabled") { _, _ in
      return [ "enabled": self.analyser.isRunning ]
    }

    /// Off until somebody asks. A transform running behind a window nobody
    /// opened is battery spent on nothing.
    self.on(.POST, "/enabled") { data, _ in
      let enabled = data["enabled"] as? Bool
      if (enabled == nil) {
        throw "Invalid 'enabled' value, must be a valid Boolean value"
      }
      if (enabled!) {
        self.analyser.start()
      } else {
        self.analyser.stop()
      }
      return "Analyzer enabled state has been set"
    }

    self.on(.GET, "/frequencies") { _, _ in
      return JSON(SpectrumAnalyser.frequencies)
    }

    volumesListener = analyser.volumes.on { spectrum in
      // The bridge hands its calls to a web view, which only accepts them on
      // the main thread, and the analyser measures on a queue of its own.
      DispatchQueue.main.async {
        // Both readings travel in the one event rather than in two: at thirty
        // frames a second a second event would double the trips across the
        // bridge to say something measured in the same window.
        self.send(to: "/volumes", data: JSON([
          "bands": spectrum.bands,
          "peak": spectrum.peak
        ] as [String: Any]))
      }
    }
  }
}
