//
//  AudioDeviceEvents.swift
//  eqMac
//
//  Created by Roman Kisil on 14/11/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//
//  Rewritten to listen on CoreAudio directly instead of AMCoreAudio's
//  NotificationCenter. The static API is unchanged so call sites still work.
//

import Foundation
import CoreAudio
import EmitterKit

struct ListChangedDevices {
  let added: [AudioDevice]
  let removed: [AudioDevice]
}

enum AudioDeviceEventType {
  case isJackConnectedChanged
  case isRunningSomewhereChanged
  case volumeChanged
  case muteChanged
  case isAliveChanged
  case nominalSampleRateChanged
  case availableNominalSampleRatesChanged
  case clockSourceChanged
  case nameChanged
  case listChanged
  case isRunningChanged
  case preferredChannelsForStereoChanged
  case hogModeChanged
  case outputChanged
  case inputChanged
  case systemDeviceChanged
}

class AudioDeviceEvents {
  static var events = AudioDeviceEvents()
  static var listeners: [EmitterKit.EventListener<AudioDevice>] = []

  var subscribed = false

  // Per Device
  let isJackConnectedChangedEvent = EmitterKit.Event<AudioDevice>()
  let isRunningSomewhereChangedEvent = EmitterKit.Event<AudioDevice>()
  var volumeChangedEvent = EmitterKit.Event<AudioDevice>()
  let muteChangedEvent = EmitterKit.Event<AudioDevice>()
  var isAliveChangedEvent = EmitterKit.Event<AudioDevice>()
  var nominalSampleRateChangedEvent = EmitterKit.Event<AudioDevice>()
  let availableNominalSampleRatesChangedEvent = EmitterKit.Event<AudioDevice>()
  let clockSourceChangedEvent = EmitterKit.Event<AudioDevice>()
  let nameChangedEvent = EmitterKit.Event<AudioDevice>()
  let listChangedEvent = EmitterKit.Event<AudioDevice>()
  let isRunningChangedEvent = EmitterKit.Event<AudioDevice>()
  let preferredChannelsForStereoChangedEvent = EmitterKit.Event<AudioDevice>()
  let hogModeChangedEvent = EmitterKit.Event<AudioDevice>()

  // Hardware Events
  let deviceListChangedEvent = EmitterKit.Event<ListChangedDevices>()
  static var deviceListChangedListeners: [EmitterKit.EventListener<ListChangedDevices>] = []

  let outputChangedEvent = EmitterKit.Event<AudioDevice>()
  let inputChangedEvent = EmitterKit.Event<AudioDevice>()
  let systemDeviceChangedEvent = EmitterKit.Event<AudioDevice>()

  // MARK: - CoreAudio plumbing

  private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

  /// CoreAudio delivers property notifications by dispatching *synchronously*
  /// onto this queue, so it must never be a queue that itself makes blocking
  /// CoreAudio calls. The main queue does: tearing the pipeline down calls
  /// AudioDeviceStop and AudioHardwareDestroyAggregateDevice from there, and
  /// destroying a device we hold listeners on makes CoreAudio wait for this
  /// queue while this queue waits for CoreAudio. That deadlock only breaks on
  /// an internal timeout, after which creating the replacement tap returns
  /// noErr with no object and the pipeline is silently lost.
  private static let listenerQueue = DispatchQueue(label: "audio-device-events")

  /// Device-scoped properties we forward as events.
  private static let deviceSelectors: [(AudioObjectPropertySelector, AudioDeviceEventType)] = [
    (kAudioDevicePropertyVolumeScalar, .volumeChanged),
    (kAudioDevicePropertyMute, .muteChanged),
    (kAudioDevicePropertyDeviceIsAlive, .isAliveChanged),
    (kAudioDevicePropertyJackIsConnected, .isJackConnectedChanged),
    (kAudioDevicePropertyNominalSampleRate, .nominalSampleRateChanged),
    (kAudioDevicePropertyAvailableNominalSampleRates, .availableNominalSampleRatesChanged),
    (kAudioDevicePropertyClockSource, .clockSourceChanged),
    (kAudioObjectPropertyName, .nameChanged),
    (kAudioDevicePropertyDeviceIsRunning, .isRunningChanged),
    (kAudioDevicePropertyDeviceIsRunningSomewhere, .isRunningSomewhereChanged),
    (kAudioDevicePropertyPreferredChannelsForStereo, .preferredChannelsForStereoChanged),
    (kAudioDevicePropertyHogMode, .hogModeChanged)
  ]

  /// System-scoped properties we forward as events.
  private static let hardwareSelectors: [AudioObjectPropertySelector] = [
    kAudioHardwarePropertyDevices,
    kAudioHardwarePropertyDefaultOutputDevice,
    kAudioHardwarePropertyDefaultInputDevice,
    kAudioHardwarePropertyDefaultSystemOutputDevice
  ]

  /// Blocks are retained so they can be removed again on unsubscribe.
  private var registered: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
  private var knownDevices: [AudioDevice] = []

  private func addListener (
    _ objectID: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    _ handler: @escaping () -> Void
  ) {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeWildcard,
      mElement: kAudioObjectPropertyElementWildcard
    )

    // Handlers reach Application state, the store and the UI, so they stay on
    // the main queue; hopping asynchronously is what keeps CoreAudio from
    // waiting on it.
    let block: AudioObjectPropertyListenerBlock = { _, _ in
      DispatchQueue.main.async { handler() }
    }

    guard AudioObjectAddPropertyListenerBlock(
      objectID, &address, AudioDeviceEvents.listenerQueue, block
    ) == noErr else { return }

    registered.append((objectID, address, block))
  }

  private func attach (to device: AudioDevice) {
    for (selector, type) in AudioDeviceEvents.deviceSelectors {
      addListener(device.id, selector) { [weak self] in
        guard let self = self else { return }
        AudioDeviceEvents.getEventEmitterFromEventType(type).emit(device)
        _ = self
      }
    }
  }

  private func handleDeviceListChanged () {
    let current = AudioDevice.allDevices()
    let currentIDs = Set(current.map { $0.id })
    let knownIDs = Set(knownDevices.map { $0.id })

    let added = current.filter { !knownIDs.contains($0.id) }
    let removed = knownDevices.filter { !currentIDs.contains($0.id) }

    knownDevices = current
    for device in added { attach(to: device) }

    let addedHardware = added.filter { $0.isHardware }
    let removedHardware = removed.filter { $0.isHardware }

    if !addedHardware.isEmpty || !removedHardware.isEmpty {
      deviceListChangedEvent.emit(
        ListChangedDevices(added: addedHardware, removed: removedHardware)
      )
    }
  }

  func subscribe () {
    guard !subscribed else { return }
    subscribed = true

    knownDevices = AudioDevice.allDevices()
    for device in knownDevices { attach(to: device) }

    for selector in AudioDeviceEvents.hardwareSelectors {
      addListener(AudioDeviceEvents.systemObject, selector) { [weak self] in
        guard let self = self else { return }
        switch selector {
        case kAudioHardwarePropertyDevices:
          self.handleDeviceListChanged()
        case kAudioHardwarePropertyDefaultOutputDevice:
          if let device = AudioDevice.defaultOutputDevice() { self.outputChangedEvent.emit(device) }
        case kAudioHardwarePropertyDefaultInputDevice:
          if let device = AudioDevice.defaultInputDevice() { self.inputChangedEvent.emit(device) }
        case kAudioHardwarePropertyDefaultSystemOutputDevice:
          if let device = AudioDevice.defaultSystemOutputDevice() { self.systemDeviceChangedEvent.emit(device) }
        default: break
        }
      }
    }
  }

  func unsubscribe () {
    for (objectID, address, block) in registered {
      var address = address
      AudioObjectRemovePropertyListenerBlock(
        objectID, &address, AudioDeviceEvents.listenerQueue, block
      )
    }
    registered.removeAll()
    knownDevices.removeAll()
    subscribed = false
  }

  static func subscribe () {
    events.subscribe()
  }

  static func unsubscribe () {
    events.unsubscribe()
  }

  static func recreateEventEmitters (_ eventsToRecreate: [AudioDeviceEventType]) throws {
    subscribe()
    for event in eventsToRecreate {
      switch event {
      case .isAliveChanged:
        events.isAliveChangedEvent = EmitterKit.Event<AudioDevice>()
      case .volumeChanged:
        events.volumeChangedEvent = EmitterKit.Event<AudioDevice>()
      case .nominalSampleRateChanged:
        events.nominalSampleRateChangedEvent = EmitterKit.Event<AudioDevice>()
      default:
        throw "This event can't be recreated, or change this code"
      }
    }
  }

  static func getEventEmitterFromEventType (_ event: AudioDeviceEventType) -> EmitterKit.Event<AudioDevice> {
    switch event {
    case .isRunningSomewhereChanged: return events.isRunningSomewhereChangedEvent
    case .volumeChanged: return events.volumeChangedEvent
    case .muteChanged: return events.muteChangedEvent
    case .isAliveChanged: return events.isAliveChangedEvent
    case .isJackConnectedChanged: return events.isJackConnectedChangedEvent
    case .nominalSampleRateChanged: return events.nominalSampleRateChangedEvent
    case .availableNominalSampleRatesChanged: return events.availableNominalSampleRatesChangedEvent
    case .clockSourceChanged: return events.clockSourceChangedEvent
    case .nameChanged: return events.nameChangedEvent
    case .listChanged: return events.listChangedEvent
    case .isRunningChanged: return events.isRunningChangedEvent
    case .preferredChannelsForStereoChanged: return events.preferredChannelsForStereoChangedEvent
    case .hogModeChanged: return events.hogModeChangedEvent
    case .outputChanged: return events.outputChangedEvent
    case .inputChanged: return events.inputChangedEvent
    case .systemDeviceChanged: return events.systemDeviceChangedEvent
    }
  }

  @discardableResult
  static func on (_ event: AudioDeviceEventType, retain: Bool = true, _ handler: @escaping (AudioDevice) -> Void) -> EmitterKit.EventListener<AudioDevice> {
    events.subscribe()
    let emitter = getEventEmitterFromEventType(event)
    let listener: EmitterKit.EventListener<AudioDevice> = emitter.on(handler)
    if (retain) {
      listeners.append(listener)
    }
    return listener
  }

  @discardableResult
  static func on (_ event: AudioDeviceEventType, onDevice device: AudioDevice, retain: Bool = true, _ handler: @escaping () -> Void) -> EmitterKit.EventListener<AudioDevice> {
    return on(event, retain: retain) { if $0.id == device.id { handler() }}
  }

  @discardableResult
  static func once (_ event: AudioDeviceEventType, _ handler: @escaping (AudioDevice) -> Void) -> EmitterKit.EventListener<AudioDevice> {
    events.subscribe()
    let emitter = getEventEmitterFromEventType(event)
    let listener: EmitterKit.EventListener<AudioDevice> = emitter.once(handler: handler)
    return listener
  }

  static func once (_ event: AudioDeviceEventType, onDevice device: AudioDevice, _ handler: @escaping () -> Void) {
    let emitter = getEventEmitterFromEventType(event)
    emitter.once { d in
      if (d.id == device.id) {
        handler()
      } else {
        once(event, onDevice: device, handler)
      }
    }
  }

  @discardableResult
  static func onDeviceListChanged (_ handler: @escaping (ListChangedDevices) -> Void) -> EmitterKit.EventListener<ListChangedDevices> {
    events.subscribe()
    let listener = events.deviceListChangedEvent.on(handler)
    deviceListChangedListeners.append(listener)
    return listener
  }

  static func start () {
    subscribe()
    for listener in listeners {
      listener.isListening = true
    }
  }

  static func stop () {
    unsubscribe()
    for listener in listeners {
      listener.isListening = false
    }
    listeners.removeAll()

    for listener in deviceListChangedListeners {
      listener.isListening = false
    }
    deviceListChangedListeners.removeAll()
  }
}
