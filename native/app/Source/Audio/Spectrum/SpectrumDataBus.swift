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
  private var volumesListener: EventListener<[Double]>?

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

    volumesListener = analyser.volumes.on { volumes in
      // The bridge hands its calls to a web view, which only accepts them on
      // the main thread, and the analyser measures on a queue of its own.
      DispatchQueue.main.async {
        self.send(to: "/volumes", data: JSON(volumes))
      }
    }
  }
}
