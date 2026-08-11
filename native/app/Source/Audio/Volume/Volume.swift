//
//  Volume.swift
//  Toneka
//
//  Created by Roman Kisil on 14/05/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import ReSwift
import EmitterKit
import AVFoundation

class Volume: StoreSubscriber {
  var state: VolumeState {
    return Application.store.state.volume
  }

  // MARK: - Events
  static var gainChanged = EmitterKit.Event<Double>()
  static var balanceChanged = EmitterKit.Event<Double>()
  static var mutedChanged = EmitterKit.Event<Bool>()
  static let boostEnabledChanged = EmitterKit.Event<Bool>()

  var mixer = AVAudioMixerNode()

  // MARK: - Properties

  /// Writes `volume` to the device, unless the device already holds it.
  ///
  /// Some devices answer a read with a different value than they were written:
  /// a Bluetooth headset quantises to its own scale, so writing 0.3125 reads
  /// back as 0.625 and writing that reads back as 0.3125 again. Every write
  /// raises a volume-changed notification, which is read off the device and
  /// dispatched as a new gain, which is written once more -- the write and the
  /// notification keep calling each other and the volume audibly oscillates.
  ///
  /// The cycle only closes when a value that came *from* the device is written
  /// back *to* it, and that write is always redundant. Dropping it leaves the
  /// user's own volume changes untouched, because those do differ from what
  /// the device currently holds.
  private static func setDeviceVolume (_ device: AudioDevice, _ volume: Double) {
    if let current = device.virtualMasterVolume(direction: .playback),
       abs(Double(current) - volume) < 0.0001 {
      return
    }
    device.setVirtualMasterVolume(Float32(volume), direction: .playback)
  }

  // None of the four below carry a declared default. A stored property with
  // one is already initialised by the time `init` runs, so assigning it there
  // counts as a change and fires the observer; without one the same assignment
  // is the initialisation itself and stays silent. Every observer here ends in
  // re-applying `gain`, so a default would mean writing it to the output
  // device before `gain` holds the value this object was built for.
  var gain: Double {
    didSet {
      let device: AudioDevice! = Application.selectedDevice
      let volumeSupported = device.outputVolumeSupported
      let balanceSupported = device.outputBalanceSupported
      var virtualVolume: Double = 1
      if (gain <= 1) {
        if (volumeSupported) {
          Application.ignoreNextVolumeEvent = true
          Volume.setDeviceVolume(device, gain)
        } else {
          virtualVolume = gain
        }

        if (balanceSupported) {
          device.setVirtualMasterBalance(Float32(balance.remap(inMin: -1, inMax: 1, outMin: 0, outMax: 1)), direction: .playback)
          mixer.pan = 0
        } else {
          mixer.pan = Float(balance)
        }
      } else { // gain > 1
        if (!boostEnabled) {
          Application.dispatchAction(VolumeAction.setGain(1, false))
          return
        }
        if (volumeSupported) {
          Application.ignoreNextVolumeEvent = true
          Volume.setDeviceVolume(device, 1.0)
        }
        virtualVolume = gain.remap(inMin: 1, inMax: 2, outMin: 1, outMax: 6)

        if (balanceSupported) {
          device.setVirtualMasterBalance(Float32(balance.remap(inMin: -1, inMax: 1, outMin: 0, outMax: 1)), direction: .playback)
          mixer.pan = 0
        } else {
          mixer.pan = Float(balance)
        }
      }

      mixer.outputVolume = Float(virtualVolume)
      Volume.gainChanged.emit(gain)
      Application.ignoreNextVolumeEvent = false
      
      if (gain == 0) {
        Application.dispatchAction(VolumeAction.setMuted(true))
      } else if (muted) {
        Application.dispatchAction(VolumeAction.setMuted(false))
      }
    }
  }
  
  var muted: Bool {
    didSet {
      Application.selectedDevice?.mute = muted
      if (muted) {
        mixer.outputVolume = 0
      } else {
        (gain = gain)
      }
      Volume.mutedChanged.emit(muted)
    }
  }
  
  var balance: Double {
    didSet {
      if (balance > 1) {
        balance = 1
        return
      }
      if (balance < -1) {
        balance = -1
        return
      }
      (gain = gain)
      Volume.balanceChanged.emit(balance)
    }
  }

  var boostEnabled: Bool {
    didSet {
      if (boostEnabled != oldValue) {
        Volume.boostEnabledChanged.emit(boostEnabled)
        (gain = gain)
      }
    }
  }

  // MARK: - State
  typealias StoreSubscriberStateType = VolumeState
  
  private let changeGainThread = DispatchQueue(label: "change-volume", qos: .userInteractive)
  private var latestChangeGainTask: DispatchWorkItem?
  private func performOnChangeGainThread (_ code: @escaping () -> Void) {
    latestChangeGainTask?.cancel()
    latestChangeGainTask = DispatchWorkItem(block: code)
    changeGainThread.async(execute: latestChangeGainTask!)
  }

  func newState(state: VolumeState) {
    if (state.balance != balance) {
      performOnChangeGainThread { [weak self] in
        guard self != nil else { return }
        if (state.transition) {
          Transition.perform(from: self!.balance, to: state.balance) { balance in
            self!.balance = balance
          }
        } else {
          self!.balance = state.balance
        }
      }
    }
    
    if (state.gain != gain) {
      performOnChangeGainThread { [weak self] in
        guard self != nil else { return }
        if (state.transition) {
          Transition.perform(from: self!.gain, to: state.gain) { [weak self] gain in
            self?.gain = gain
          }
        } else {
          self!.gain = state.gain
        }
      }
    }
    
    if (state.muted != muted) {
      performOnChangeGainThread { [weak self] in
        guard self != nil else { return }
        self!.muted = state.muted
      }
    }

    if (state.boostEnabled != boostEnabled) {
      self.boostEnabled = state.boostEnabled
    }
  }
  
  // MARK: - Initialization
  init () {
    Console.log("Creating Volume")
    // The store directly rather than `state`: that one reads through `self`,
    // which is off limits until every stored property below has a value.
    let initial = Application.store.state.volume
    boostEnabled = initial.boostEnabled
    gain = initial.gain
    balance = initial.balance
    muted = initial.muted
    setupStateListener()
  }
  
  func setupStateListener () {
    Application.store.subscribe(self) { subscription in
      subscription.select { state in state.volume }
    }
  }

  /// Applies the current state to the output device and to `mixer`. Building
  /// this object only records the state -- the observers that carry it outward
  /// stay silent during initialisation -- and attaching a node to an
  /// AVAudioEngine resets its outputVolume to 1 regardless, so the graph has to
  /// exist before any of it means anything.
  ///
  /// Assigning `muted` covers both cases: muted silences the mixer outright,
  /// unmuted re-runs the gain path that decides between hardware volume and
  /// the mixer.
  func postSetup () {
    (muted = muted)

    // Announcing the balance the way assigning `muted` above announces the
    // gain. Nothing else does: the gain path applies balance to the device and
    // to the mixer without raising the event, and the assignments in `init`
    // raise nothing at all.
    //
    // Which matters most when the output is changed from Toneka's own list.
    // That route tears the engine down before building the replacement, so the
    // `Volume` that would have seen the new balance arrive in the store is
    // already gone by the time it does, and the one built afterwards receives
    // it as its initial value rather than as a change. Without this the
    // interface is left showing the balance of the device before the switch.
    Volume.balanceChanged.emit(balance)
  }

  deinit {
    Application.store.unsubscribe(self)
  }
}
