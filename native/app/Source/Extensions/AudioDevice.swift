import Foundation
import CoreAudio
import SwiftyUserDefaults
import CoreFoundation
import EmitterKit

extension AudioDevice {
  func canBeDefaultDevice (direction: Direction) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
      mScope: AudioDevice.scope(direction: direction),
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = UInt32(MemoryLayout<UInt32>.size)
    
    var result: UInt32 = 0
    
    checkErr(AudioObjectGetPropertyData(self.id, &address, 0, nil, &size, &result))
    return result == 1
  }
  // `nonmutating` throughout: AudioDevice is a value type wrapping an object ID,
  // and these setters write to CoreAudio/storage rather than to `self`.
  var stashedVolume: Double {
    get {
      return Storage.double(forKey: "stashedVolume:\(self.id)")
    }
    nonmutating set {
      Storage.set(newValue, forKey: "stashedVolume:\(self.id)")
    }
  }
  var json: [String: AnyObject] {
    return AudioDevice.toJSON(self)
  }
  
  var outputVolumeSupported: Bool {
    return self.virtualMasterVolume(direction: .playback) != nil
  }
  
  var outputBalanceSupported: Bool {
    return self.virtualMasterBalance(direction: .playback) != nil
  }
  
  var isActiveSettable: Bool {
    return false //AudioObjectHasProperty(self.id, kAudioPlugInCustomPropertyDeviceActive)
  }
  
  /// True for the private aggregate device eqMac builds around its tap, which
  /// must never be offered to the user as an output.
  var isDriver: Bool {
    get {
      return self.uid == AggregateDevice.uid
    }
  }
  
  var isCAAggregate: Bool {
    get {
      return self.name.contains("CADefaultDeviceAggregate")
    }
  }
  
  var isHardware: Bool {
    get {
      return !self.isDriver && !self.isCAAggregate
    }
  }
  
  var mute: Bool {
    get {
      if (self.canMuteVirtualMasterChannel(direction: .playback)) {
        return self.isMuted(channel: 0, direction: .playback)!
      } else {
        return (1...self.channels(direction: .playback).intValue).allSatisfy { self.isMuted(channel: UInt32($0), direction: .playback) ?? false }
      }
    }
    nonmutating set {
      if (self.canMuteVirtualMasterChannel(direction: .playback)) {
        self.setMute(newValue, channel: 0, direction: .playback)
      } else {
        let channels = self.channels(direction: .playback).intValue
        if channels >= 1 {
          for channel in 1...self.channels(direction: .playback).intValue {
            self.setMute(newValue, channel: UInt32(channel), direction: .playback)
          }
        }
      }
    }
  }
  
  var decibelRange: ClosedRange<Double> {
    var propertyAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeRangeDecibels,
                                                     mScope: kAudioDevicePropertyScopeOutput,
                                                     mElement: kAudioObjectPropertyElementMain)
    var value = AudioValueRange(mMinimum: 0, mMaximum: 0)
    // Try master first
    
    if checkErr(AudioDevice.getPropertyData(self.id, address: propertyAddress, andValue: &value)) != nil {
      propertyAddress.mElement = 1
      // Try single channel
      checkErr(AudioDevice.getPropertyData(self.id, address: propertyAddress, andValue: &value))
    }
    
    return Double(value.mMinimum)...Double(value.mMaximum)
  }
  
  var sourceName: String? {
    let scope = isInputOnlyDevice() ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
    var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDataSource, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    
    var sourceCode: UInt32 = 0
    var propSize = UInt32(MemoryLayout<UInt32>.size)
    
    let err = AudioObjectGetPropertyData(id, &address, 0, nil, &propSize, &sourceCode)
    if err != noErr {
      return nil
    }
    
    var name: CFString = "" as CFString

    address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDataSourceNameForIDCFString,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )

    propSize = UInt32(MemoryLayout<AudioValueTranslation>.size)

    // AudioValueTranslation holds raw pointers to both buffers, so they have to
    // stay valid for the whole call. Taking `&sourceCode` inline lets them
    // dangle before CoreAudio reads them.
    withUnsafeMutablePointer(to: &sourceCode) { inputPointer in
      withUnsafeMutablePointer(to: &name) { outputPointer in
        var translation = AudioValueTranslation(
          mInputData: UnsafeMutableRawPointer(inputPointer),
          mInputDataSize: UInt32(MemoryLayout<UInt32>.size),
          mOutputData: UnsafeMutableRawPointer(outputPointer),
          mOutputDataSize: UInt32(MemoryLayout<CFString>.size)
        )
        AudioObjectGetPropertyData(id, &address, 0, nil, &propSize, &translation)
      }
    }

    let stringName = name as String
    return stringName == "" ? nil : stringName
  }
  
  public func bufferFrameSize(direction: Direction) -> UInt32 {
    let propertyAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyBufferFrameSize,
                                                     mScope: AudioDevice.scope(direction: direction), mElement: 0)
    var value: UInt32 = 0
    if let err = checkErr(AudioDevice.getPropertyData(self.id, address: propertyAddress, andValue: &value)) {
      Console.log(err)
      return 0
    }
    return value
  }
  
  static public func getOutputDeviceFromUID (UID: String) -> AudioDevice? {
    let device: AudioDevice? = AudioDevice.allOutputDevices().first( where: { (device) -> Bool in
      let uid = device.uid
      return uid == UID
    })
    
    return device
  }
  
  static public func getInputDeviceFromUID (UID: String) -> AudioDevice? {
    let device: AudioDevice? = AudioDevice.allInputDevices().first( where: { (device) -> Bool in
      return device.uid == UID
    })
    return device
  }
  
  static public var currentOutputDevice: AudioDevice {
    get { return AudioDevice.defaultOutputDevice()! }
    set {
      newValue.setAsDefaultOutputDevice()
    }
  }

  static public var currentSystemDevice: AudioDevice {
    get { return AudioDevice.defaultSystemOutputDevice()! }
    set { newValue.setAsDefaultSystemDevice() }
  }
  
  static public var currentInputDevice: AudioDevice {
    get { return AudioDevice.defaultInputDevice()! }
    set {
      newValue.setAsDefaultInputDevice()
    }
  }
  
  static public var builtInOutputDevice: AudioDevice {
    get {
      let outputDevices = AudioDevice.allOutputDevices()
      Console.log(outputDevices)
      let device: AudioDevice? = outputDevices.first( where: { (device) -> Bool in
        device.transportType == TransportType.builtIn
      })
      return device!
    }
  }
  
  static public var builtInInputDevice: AudioDevice {
    get {
      let device: AudioDevice? = AudioDevice.allInputDevices().first( where: { (device) -> Bool in
        device.transportType == TransportType.builtIn
      })
      return device!
    }
  }
  
  static func toJSON (_ device: AudioDevice) -> [String: AnyObject] {
    return [
      "id": device.id as AnyObject,
      "name": (device.sourceName ?? device.name) as AnyObject,
      "transportType": device.transportType?.rawValue as AnyObject
    ]
  }
  
  public static func scope(direction: Direction) -> AudioObjectPropertyScope {
    return .playback == direction ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput
  }
  
  public static func getPropertyData<T>(_ objectID: AudioObjectID, address: AudioObjectPropertyAddress, andValue value: inout T) -> OSStatus {

    var theAddress = address
    var size = UInt32(MemoryLayout<T>.size)
    return withUnsafeMutablePointer(to: &value) {
      AudioObjectGetPropertyData(objectID, &theAddress, UInt32(0), nil, &size, $0)
    }
  }

  public static func getPropertyDataSize(_ objectID: AudioObjectID, address: AudioObjectPropertyAddress, size: inout UInt32) -> (OSStatus) {
      var theAddress = address

      return AudioObjectGetPropertyDataSize(objectID, &theAddress, 0, nil, &size)
  }
}

