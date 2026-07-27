//
//  CoreAudioProperty.swift
//  eqMac
//
//  Thin CoreAudio property-access layer.
//
//  Replaces AMCoreAudio, whose upstream repo was renamed to SimplyCoreAudio and
//  whose 3.4 pod no longer resolves any sources. The API surface here is kept
//  deliberately identical to AMCoreAudio's so call sites don't have to change.
//

import Foundation
import CoreAudio

/// Direction of an audio stream, from the device's point of view.
public enum Direction {
  case playback
  case recording

  var scope: AudioObjectPropertyScope {
    switch self {
    case .playback: return kAudioObjectPropertyScopeOutput
    case .recording: return kAudioObjectPropertyScopeInput
    }
  }
}

/// How a device is attached to the system. Raw values match `kAudioDeviceTransportType*`.
public enum TransportType: String {
  case unknown
  case builtIn
  case aggregate
  case virtual
  case pci
  case usb
  case fireWire
  case bluetooth
  case bluetoothLE
  case hdmi
  case displayPort
  case airPlay
  case avb
  case thunderbolt

  static func from (_ raw: UInt32) -> TransportType {
    switch raw {
    case kAudioDeviceTransportTypeBuiltIn: return .builtIn
    case kAudioDeviceTransportTypeAggregate: return .aggregate
    case kAudioDeviceTransportTypeVirtual: return .virtual
    case kAudioDeviceTransportTypePCI: return .pci
    case kAudioDeviceTransportTypeUSB: return .usb
    case kAudioDeviceTransportTypeFireWire: return .fireWire
    case kAudioDeviceTransportTypeBluetooth: return .bluetooth
    case kAudioDeviceTransportTypeBluetoothLE: return .bluetoothLE
    case kAudioDeviceTransportTypeHDMI: return .hdmi
    case kAudioDeviceTransportTypeDisplayPort: return .displayPort
    case kAudioDeviceTransportTypeAirPlay: return .airPlay
    case kAudioDeviceTransportTypeAVB: return .avb
    case kAudioDeviceTransportTypeThunderbolt: return .thunderbolt
    default: return .unknown
    }
  }
}

/// Namespaced helpers for reading and writing `AudioObject` properties.
///
/// Every CoreAudio property access follows the same shape — build an address,
/// ask for the size, allocate, read. These wrap that boilerplate so the rest of
/// the codebase never touches `AudioObjectGetPropertyData` directly.
enum CAProperty {

  static func address (
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    _ element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
  ) -> AudioObjectPropertyAddress {
    return AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
  }

  static func has (_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
    var address = address
    return AudioObjectHasProperty(objectID, &address)
  }

  static func isSettable (_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
    guard has(objectID, address) else { return false }
    var address = address
    var settable: DarwinBoolean = false
    guard AudioObjectIsPropertySettable(objectID, &address, &settable) == noErr else { return false }
    return settable.boolValue
  }

  static func dataSize (_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> UInt32? {
    var address = address
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size) == noErr else { return nil }
    return size
  }

  /// Reads a single fixed-size value.
  static func value<T> (_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress, default fallback: T) -> T? {
    guard has(objectID, address) else { return nil }
    var address = address
    var value = fallback
    var size = UInt32(MemoryLayout<T>.size)
    // The pointer must stay valid for the whole call, so scope it explicitly
    // rather than passing `&value` inline.
    let status = withUnsafeMutablePointer(to: &value) {
      AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
    }
    guard status == noErr else { return nil }
    return value
  }

  /// Reads a variable-length array property.
  static func array<T> (_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress, of type: T.Type) -> [T]? {
    guard let size = dataSize(objectID, address), size > 0 else { return nil }
    let count = Int(size) / MemoryLayout<T>.size
    guard count > 0 else { return [] }

    var address = address
    var size32 = size
    var buffer = [T](unsafeUninitializedCapacity: count) { _, initialized in initialized = count }

    let status = buffer.withUnsafeMutableBytes { raw -> OSStatus in
      return AudioObjectGetPropertyData(objectID, &address, 0, nil, &size32, raw.baseAddress!)
    }

    guard status == noErr else { return nil }
    return buffer
  }

  static func string (_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String? {
    guard has(objectID, address) else { return nil }
    var address = address
    // CoreAudio hands back a +1 retained CFString, so take ownership via
    // Unmanaged instead of bridging a raw pointer (which would leak).
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = withUnsafeMutablePointer(to: &value) {
      AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
    }
    guard status == noErr, let string = value else { return nil }
    return string.takeRetainedValue() as String
  }

  @discardableResult
  static func setValue<T> (_ objectID: AudioObjectID, _ address: AudioObjectPropertyAddress, _ value: T) -> Bool {
    guard isSettable(objectID, address) else { return false }
    var address = address
    var value = value
    let size = UInt32(MemoryLayout<T>.size)
    return withUnsafeMutablePointer(to: &value) {
      AudioObjectSetPropertyData(objectID, &address, 0, nil, size, $0) == noErr
    }
  }

  /// Translates one value into another via `AudioValueTranslation`.
  static func translate<In, Out> (
    _ objectID: AudioObjectID,
    _ address: AudioObjectPropertyAddress,
    input: In,
    output: Out
  ) -> Out? {
    guard has(objectID, address) else { return nil }
    var address = address
    var input = input
    var output = output

    // AudioValueTranslation stores raw pointers to both buffers, so those
    // pointers have to outlive the call that reads them. Taking `&input`
    // inline would let them dangle.
    let status = withUnsafeMutablePointer(to: &input) { inputPointer in
      withUnsafeMutablePointer(to: &output) { outputPointer -> OSStatus in
        var translation = AudioValueTranslation(
          mInputData: UnsafeMutableRawPointer(inputPointer),
          mInputDataSize: UInt32(MemoryLayout<In>.size),
          mOutputData: UnsafeMutableRawPointer(outputPointer),
          mOutputDataSize: UInt32(MemoryLayout<Out>.size)
        )
        var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
        return AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &translation)
      }
    }

    guard status == noErr else { return nil }
    return output
  }
}
