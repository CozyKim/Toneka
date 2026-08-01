//
//  Application.swift
//  eqMac
//
//  Created by Roman Kisil on 22/01/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation
import Cocoa
import Dispatch
import EmitterKit
import AVFoundation
import SwiftyUserDefaults
import SwiftyJSON
import ServiceManagement
import ReSwift
import Shared

enum VolumeChangeDirection: String {
  case UP = "UP"
  case DOWN = "DOWN"
}

class Application {
  static var bundleId: String {
    return Bundle.main.bundleIdentifier!
  }
  static var tapEngine: TapEngine?
  static var engineCreated = EmitterKit.Event<Void>()
  static var outputCreated = EmitterKit.Event<Void>()

  static var selectedDevice: AudioDevice?
  static var selectedDeviceIsAliveListener: EventListener<AudioDevice>?
  static var selectedDeviceVolumeChangedListener: EventListener<AudioDevice>?
  static var selectedDeviceMuteChangedListener: EventListener<AudioDevice>?
  static var selectedDeviceSampleRateChangedListener: EventListener<AudioDevice>?
  static var justChangedSelectedDeviceVolume = false

  static let audioPipelineIsRunning = EmitterKit.Event<Void>()
  static var audioPipelineIsRunningListener: EmitterKit.EventListener<Void>?
  private static var ignoreEvents = false
  private static var ignoreVolumeEvents = false

  static var settings: Settings!
    
    
  static var ui: UI!
  static let volumeHUD = VolumeHUD()
    
    

  static var dataBus: ApplicationDataBus!
  static let error = EmitterKit.Event<String>()

  static let store: Store = Store(
    reducer: ApplicationStateReducer,
    state: ApplicationState.load(),
    middleware: []
  )

  static let enabledChanged = EmitterKit.Event<Bool>()
  static var enabledChangedListener: EmitterKit.EventListener<Bool>?
  static var enabled = store.state.enabled {
    didSet {
      if (oldValue != enabled) {
        enabledChanged.emit(enabled)
      }
    }
  }
  
  static var equalizersTypeChangedListener: EventListener<EqualizerType>?

  static public func start () {
    self.settings = Settings()

    if enabled {
      setupAudio()
    }

    setupListeners()

    setupUI {
      if (User.isFirstLaunch) {
        UI.show()
      } else {
        UI.close()
      }
    }
  }

  private static func setupListeners () {
    enabledChangedListener = enabledChanged.on { enabled in
      if (enabled) {
        setupAudio()
      } else {
        stopSave {}
      }
    }
    
    equalizersTypeChangedListener = Equalizers.typeChanged.on { _ in
      if (enabled) {
        stopSave {}
        Async.delay(100) {
          setupAudio()
        }
      }
      
    }
  }
  
  private static var settingUpAudio = false
  private static func setupAudio () {
    if (settingUpAudio) { return }
    settingUpAudio = true
    Console.log("Setting up Audio Engine")
    setupDeviceEvents()
    startPassthrough {
      settingUpAudio = false
    }
  }
  
  static var ignoreNextVolumeEvent = false
  static var ignoreNextMuteEvent = false

  static func setupDeviceEvents () {
    AudioDeviceEvents.on(.outputChanged) { device in
      if Outputs.isDeviceAllowed(device) {
        if ignoreEvents {
          dataBus.send(to: "/outputs/selected", data: JSON([ "id": device.id ]))
          return
        }
        Console.log("outputChanged: ", device, " starting PlayThrough")
        startPassthrough()
      } else {
        // TODO: Tell the user eqMac doesn't support this device
      }
    }
    
    AudioDeviceEvents.onDeviceListChanged { list in
      if ignoreEvents { return }
      Console.log("listChanged", list)
      
      if list.added.count > 0 {
        for added in list.added {
          if Outputs.shouldAutoSelect(added) {
            selectOutput(device: added)
            break
          }
        }
      } else if (list.removed.count > 0) {
        
        let currentDeviceRemoved = list.removed.contains(where: { $0.id == selectedDevice?.id })
        
        if (currentDeviceRemoved) {
          ignoreEvents = true
          removeEngines()
          try! AudioDeviceEvents.recreateEventEmitters([.isAliveChanged, .volumeChanged, .nominalSampleRateChanged])
          // The system promotes a replacement default output on its own, so
          // rebuild the pipeline around whatever it picked.
          Async.delay(500) {
            ignoreEvents = false
            if let replacement = AudioDevice.defaultOutputDevice() {
              selectOutput(device: replacement)
            }
          }
        }
      }
      
    }
    AudioDeviceEvents.on(.isJackConnectedChanged) { device in
      if ignoreEvents { return }
      let connected = device.isJackConnected(direction: .playback)
      Console.log("isJackConnectedChanged", device, String(describing: connected))
      if (device.id != selectedDevice?.id) {
        if (connected == true) {
          selectOutput(device: device)
        }
      } else {
        stopRemoveEngines {
          Async.delay(1000) {
            // need a delay, because emitter should finish its work at first
            try! AudioDeviceEvents.recreateEventEmitters([.isAliveChanged, .volumeChanged, .nominalSampleRateChanged])
            createAudioPipeline()
          }
        }
      }
    }
  }

  static func selectOutput (device: AudioDevice) {
    ignoreEvents = true
    stopRemoveEngines {
      Async.delay(500) {
        ignoreEvents = false
        AudioDevice.currentOutputDevice = device
      }
    }
  }

  static var startingPassthrough = false
  static func startPassthrough (_ completion: (() -> Void)? = nil) {
    if (startingPassthrough) {
      completion?()
      return
    }

    startingPassthrough = true
    selectedDevice = AudioDevice.currentOutputDevice

    ignoreEvents = true
    var volume: Double = Application.store.state.volume.gain
    var muted = store.state.volume.muted
    var balance = store.state.volume.balance

    if (selectedDevice!.outputVolumeSupported) {
      volume = Double(selectedDevice!.virtualMasterVolume(direction: .playback)!)
      muted = selectedDevice!.mute
    }

    if (selectedDevice!.outputBalanceSupported) {
      balance = Double(selectedDevice!.virtualMasterBalance(direction: .playback)!).remap(
        inMin: 0,
        inMax: 1,
        outMin: -1,
        outMax: 1
      )
    }

    Application.dispatchAction(VolumeAction.setBalance(balance, false))
    Application.dispatchAction(VolumeAction.setGain(volume, false))
    Application.dispatchAction(VolumeAction.setMuted(muted))
    
    // The tap leaves the user's device selection alone, so there is nothing to
    // switch and nothing to wait for before building the pipeline.
    ignoreEvents = false
    createAudioPipeline()
    startingPassthrough = false
    completion?()
  }

  private static func createAudioPipeline () {
    guard let device = selectedDevice else { return }

    tapEngine = nil
    guard let engine = TapEngine(
      outputDevice: device,
      equalizers: Equalizers(),
      volume: Volume()
    ) else {
      Console.log("Failed to build the tap pipeline for \(device.name)")
      warnAudioCaptureUnavailable()
      return
    }

    guard engine.start() else {
      Console.log("Failed to start the tap pipeline for \(device.name)")
      warnAudioCaptureUnavailable()
      return
    }

    tapEngine = engine
    engineCreated.emit()
    outputCreated.emit()

    selectedDeviceSampleRateChangedListener = AudioDeviceEvents.on(
      .nominalSampleRateChanged,
      onDevice: selectedDevice!,
      retain: false
    ) {
      if ignoreEvents { return }
      ignoreEvents = true
      stopRemoveEngines {
        Async.delay(1000) {
          // need a delay, because emitter should finish its work at first
          try! AudioDeviceEvents.recreateEventEmitters([.isAliveChanged, .volumeChanged, .nominalSampleRateChanged])
          createAudioPipeline()
          ignoreEvents = false
        }
      }
    }

    selectedDeviceVolumeChangedListener = AudioDeviceEvents.on(
      .volumeChanged,
      onDevice: selectedDevice!,
      retain: false
    ) {
      if ignoreEvents || ignoreVolumeEvents {
        return
      }
      if ignoreNextVolumeEvent {
        ignoreNextVolumeEvent = false
        return
      }
      // Hardware volume is the single source of truth now that no driver
      // device needs to be kept in sync with it.
      guard let deviceVolume = selectedDevice!.virtualMasterVolume(direction: .playback) else { return }
      let gain = Double(deviceVolume)
      if (gain != Application.store.state.volume.gain) {
        Application.dispatchAction(VolumeAction.setGain(gain, false))
        Volume.gainChanged.emit(gain)
      }
    }

    selectedDeviceMuteChangedListener = AudioDeviceEvents.on(
      .muteChanged,
      onDevice: selectedDevice!,
      retain: false
    ) {
      if ignoreEvents { return }
      if ignoreNextMuteEvent {
        ignoreNextMuteEvent = false
        return
      }
      let muted = selectedDevice!.mute
      if (muted != Application.store.state.volume.muted) {
        Application.dispatchAction(VolumeAction.setMuted(muted))
      }
    }

    audioPipelineIsRunning.emit()
  }

  /// Without the audio capture permission the tap cannot be created, and the
  /// only symptom is that eqMac appears to run while doing nothing at all.
  /// Shown once per launch so switching devices does not repeat it.
  private static var warnedAudioCaptureUnavailable = false
  private static func warnAudioCaptureUnavailable () {
    if warnedAudioCaptureUnavailable { return }
    warnedAudioCaptureUnavailable = true

    Alert.confirm(
      title: "eqMac can't process your audio",
      message: "eqMac captures system audio in order to equalize it, which requires permission.\n\nOpen System Settings > Privacy & Security > Audio Recording and allow eqMac, then restart the app.",
      okText: "Open System Settings",
      cancelText: "Later"
    ) { openSettings in
      guard openSettings else { return }
      // Lands directly on Privacy & Security > Audio Recording.
      if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AudioCapture") {
        NSWorkspace.shared.open(url)
      }
    }
  }

  private static func setupUI (_ completion: @escaping () -> Void) {
    Console.log("Setting up UI")
    ui = UI {
      setupDataBus()
      completion()
    }
  }
  
  private static func setupDataBus () {
    Console.log("Setting up Data Bus")
    dataBus = ApplicationDataBus(bridge: UI.bridge)
  }
  
  static func volumeChangeButtonPressed (direction: VolumeChangeDirection, quarterStep: Bool = false) {
    guard !ignoreEvents, let engine = tapEngine else {
      return
    }
    let gain = engine.volume.gain

    // Devices with their own volume control are driven by the system, so we
    // only take over above 1.0 where hardware volume cannot reach. Devices
    // without one -- HDMI and DisplayPort displays -- get nothing from the
    // media keys at all, so eqMac has to apply the step itself. The driver
    // used to paper over this by always exposing a volume control.
    let deviceHasVolumeControl = selectedDevice?.outputVolumeSupported ?? false
    if (deviceHasVolumeControl && gain < 1) { return }

    let steps = quarterStep ? Constants.QUARTER_VOLUME_STEPS : Constants.FULL_VOLUME_STEPS

    var stepIndex: Int

    if direction == .UP {
      stepIndex = steps.firstIndex(where: { $0 > gain }) ?? steps.count - 1
    } else {
      stepIndex = steps.firstIndex(where: { $0 >= gain }) ?? 0
      stepIndex -= 1
      if (stepIndex < 0) {
        stepIndex = 0
      }
    }

    var newGain = steps[stepIndex]

    if (newGain > 1 && !Application.store.state.volume.boostEnabled) {
      newGain = 1
    }

    // Volume.gain applies this to the hardware or to the mixer, depending on
    // what the device supports.
    Application.dispatchAction(VolumeAction.setGain(newGain, false))

    // Reaching here means the system is not showing its own HUD for this
    // change -- either the device has no volume control, or we are above the
    // 100% the system HUD tops out at.
    volumeHUD.show(gain: newGain, muted: engine.volume.muted)
  }

  static func muteButtonPressed () {
    guard !ignoreEvents, let engine = tapEngine else { return }

    // Same split as the volume keys: a device with a mute control is handled
    // by the system, and our state follows its mute-changed event. One without
    // it -- HDMI and DisplayPort displays -- never sees the key, so eqMac has
    // to toggle its own state and let Volume silence the mixer.
    if (selectedDevice?.outputVolumeSupported ?? false) { return }

    let muted = !engine.volume.muted
    Application.dispatchAction(VolumeAction.setMuted(muted))
    volumeHUD.show(gain: engine.volume.gain, muted: muted)
  }

  /// The user may have raised the hardware volume to compensate for a negative
  /// equalizer gain. Undo that before we stop processing, otherwise the next
  /// sound plays back much louder than they expect.
  private static func restoreDeviceVolume () {
    guard let device = selectedDevice else { return }

    let globalGain = ({ () -> Double in
      let equalizersState = store.state.effects.equalizers
      let eqType = equalizersState.type

      switch eqType {
      case .basic:
        if let preset = BasicEqualizer.getPreset(id: equalizersState.basic.selectedPresetId) {
          if preset.peakLimiter {
            let gains = preset.gains
            let maxGain = [ gains.bass, gains.mid, gains.treble ].max()!
            return -maxGain
          }
        }
      case .advanced:
        if let preset = AdvancedEqualizer.getPreset(id: equalizersState.advanced.selectedPresetId) {
          return preset.gains.global
        }
      }
      return 0
    })()


    if (globalGain < 0) {
      if (device.canSetVirtualMasterVolume(direction: .playback)) {
        var decibels =
          device.volumeInDecibels(channel: 0, direction: .playback)
          ?? device.volumeInDecibels(channel: 1, direction: .playback)
          ?? 0.5
        decibels = decibels + Float(globalGain)
        let newVolume = device.decibelsToScalar(volume: decibels, channel: 0, direction: .playback) ?? device.decibelsToScalar(volume: decibels, channel: 1, direction: .playback) ?? 0.1
        device.setVirtualMasterVolume(newVolume, direction: .playback)
      } else if (device.canSetVolume(channel: 1, direction: .playback)) {
        var decibels = device.volumeInDecibels(channel: 1, direction: .playback)!
        decibels = decibels + Float(globalGain)
        for channel in 1...device.channels(direction: .playback) {
          device.setVolume(device.decibelsToScalar(volume: decibels, channel: channel, direction: .playback)!, channel: channel, direction: .playback)
        }
      }
    }
  }

  static func stopEngines (_ completion: @escaping () -> Void) {
    DispatchQueue.main.async {
      tapEngine?.stop()
      completion()
    }
  }

  static func removeEngines () {
    tapEngine = nil
  }

  static func stopRemoveEngines (_ completion: @escaping () -> Void) {
//    stopEngines {
      removeEngines()
      completion()
//    }
  }

  static func stopSave (_ completion: @escaping () -> Void) {
    Storage.synchronize()
    stopListeners()
    stopRemoveEngines {
      restoreDeviceVolume()
      completion()
    }
  }

  static func handleSleep () {
    ignoreEvents = true
    if enabled {
      stopSave {}
    }
  }

  static func handleWakeUp () {
    // Wait for devices to initialize, not sure what delay is appropriate
    Async.delay(1000) {
      if !enabled { return }
      setupAudio()
    }
  }
  
  static func quit () {
    NSApp.terminate(nil)
  }
  
  static func handleTermination (_ completion: (() -> Void)? = nil) {
    stopSave {
      if completion != nil {
        completion!()
      }
    }
  }
  
  static func restart () {
    let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
    let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = [path]
    task.launch()
    quit()
  }
  
  static func restartMac () {
    Script.apple("restart_mac")
  }
  
  static func uninstall () {
    // TODO: Implement uninstaller
    Console.log("// TODO: Download Uninstaller")
  }
  
  static func stopListeners () {
    AudioDeviceEvents.stop()
    selectedDeviceIsAliveListener?.isListening = false
    selectedDeviceIsAliveListener = nil
    
    audioPipelineIsRunningListener?.isListening = false
    audioPipelineIsRunningListener = nil
    
    selectedDeviceVolumeChangedListener?.isListening = false
    selectedDeviceVolumeChangedListener = nil

    selectedDeviceMuteChangedListener?.isListening = false
    selectedDeviceMuteChangedListener = nil

    selectedDeviceSampleRateChangedListener?.isListening = false
    selectedDeviceSampleRateChangedListener = nil
  }
  
  static var version: String {
    return Bundle.main.infoDictionary!["CFBundleVersion"] as! String
  }
  
  static func newState (_ state: ApplicationState) {
    if state.enabled != enabled {
      enabled = state.enabled
    }
  }
  
  static var supportPath: URL {
    //Create App directory if not exists:
    let fileManager = FileManager()
    let urlPaths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
    
    let appDirectory = urlPaths.first!.appendingPathComponent(Bundle.main.bundleIdentifier! ,isDirectory: true)
    var objCTrue: ObjCBool = true
    let path = appDirectory.path
    if !fileManager.fileExists(atPath: path, isDirectory: &objCTrue) {
      try! fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    return appDirectory
  }
  
  static private let dispatchActionQueue = DispatchQueue(label: "dispatchActionQueue", qos: .userInitiated)
  // Custom dispatch function. Need to execute some dispatches on the main thread
  static func dispatchAction(_ action: Action, onMainThread: Bool = true) {
    if (onMainThread) {
      DispatchQueue.main.async {
        store.dispatch(action)
      }
    } else {
      dispatchActionQueue.async {
        store.dispatch(action)
      }
    }
  }
}

