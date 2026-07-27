//
//  AudioDevice.swift
//  eqMac
//
//  Drop-in replacement for AMCoreAudio's AudioDevice.
//
//  The method signatures intentionally mirror AMCoreAudio so existing call
//  sites compile unchanged. Where AMCoreAudio used the deprecated
//  "VirtualMaster*" selectors we use the current "VirtualMain*" ones — they
//  share the same four-char codes, so behaviour is identical.
//

import Foundation
import CoreAudio
import AudioToolbox

extension UInt32 {
  /// AMCoreAudio exposed this on channel counts; kept so call sites still build.
  var intValue: Int { return Int(self) }
}

public struct AudioDevice: Equatable, Hashable, CustomStringConvertible {
  public let id: AudioObjectID

  public init (id: AudioObjectID) {
    self.id = id
  }

  /// AMCoreAudio used this to opt into its device cache. We read live, so it's inert.
  public static var register = false

  // MARK: - Identity

  public var name: String {
    return CAProperty.string(id, CAProperty.address(kAudioObjectPropertyName)) ?? "Unknown Device"
  }

  public var uid: String? {
    return CAProperty.string(id, CAProperty.address(kAudioDevicePropertyDeviceUID))
  }

  public var transportType: TransportType? {
    guard let raw: UInt32 = CAProperty.value(id, CAProperty.address(kAudioDevicePropertyTransportType), default: 0) else {
      return nil
    }
    return TransportType.from(raw)
  }

  public var description: String {
    return "<AudioDevice \(id): \(name)>"
  }

  // MARK: - Lifecycle / state

  public func isAlive () -> Bool {
    let alive: UInt32? = CAProperty.value(id, CAProperty.address(kAudioDevicePropertyDeviceIsAlive), default: 0)
    return alive == 1
  }

  public func isRunningSomewhere () -> Bool {
    let running: UInt32? = CAProperty.value(id, CAProperty.address(kAudioDevicePropertyDeviceIsRunningSomewhere), default: 0)
    return running == 1
  }

  public func isJackConnected (direction: Direction) -> Bool? {
    let address = CAProperty.address(kAudioDevicePropertyJackIsConnected, direction.scope)
    guard let connected: UInt32 = CAProperty.value(id, address, default: 0) else { return nil }
    return connected == 1
  }

  // MARK: - Channels

  /// Total channel count across every stream in the given direction.
  public func channels (direction: Direction) -> UInt32 {
    let address = CAProperty.address(kAudioDevicePropertyStreamConfiguration, direction.scope)
    guard let size = CAProperty.dataSize(id, address), size > 0 else { return 0 }

    let bufferList = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size),
      alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { bufferList.deallocate() }

    var address2 = address
    var size2 = size
    guard AudioObjectGetPropertyData(id, &address2, 0, nil, &size2, bufferList) == noErr else { return 0 }

    let abl = UnsafeMutableAudioBufferListPointer(
      bufferList.assumingMemoryBound(to: AudioBufferList.self)
    )
    return abl.reduce(0) { $0 + $1.mNumberChannels }
  }

  public func isInputOnlyDevice () -> Bool {
    return channels(direction: .recording) > 0 && channels(direction: .playback) == 0
  }

  // MARK: - Sample rate

  public func nominalSampleRate () -> Float64? {
    return CAProperty.value(id, CAProperty.address(kAudioDevicePropertyNominalSampleRate), default: Float64(0))
  }

  @discardableResult
  public func setNominalSampleRate (_ sampleRate: Float64) -> Bool {
    return CAProperty.setValue(id, CAProperty.address(kAudioDevicePropertyNominalSampleRate), sampleRate)
  }

  public func actualSampleRate () -> Float64? {
    return CAProperty.value(id, CAProperty.address(kAudioDevicePropertyActualSampleRate), default: Float64(0))
  }

  // MARK: - Timing

  public func safetyOffset (direction: Direction) -> UInt32? {
    return CAProperty.value(id, CAProperty.address(kAudioDevicePropertySafetyOffset, direction.scope), default: UInt32(0))
  }

  public func latency (direction: Direction) -> UInt32? {
    return CAProperty.value(id, CAProperty.address(kAudioDevicePropertyLatency, direction.scope), default: UInt32(0))
  }

  // MARK: - Virtual main volume (whole-device volume)

  public func virtualMasterVolume (direction: Direction) -> Float32? {
    let address = CAProperty.address(
      kAudioHardwareServiceDeviceProperty_VirtualMainVolume, direction.scope
    )
    return CAProperty.value(id, address, default: Float32(0))
  }

  @discardableResult
  public func setVirtualMasterVolume (_ volume: Float32, direction: Direction) -> Bool {
    let address = CAProperty.address(
      kAudioHardwareServiceDeviceProperty_VirtualMainVolume, direction.scope
    )
    return CAProperty.setValue(id, address, volume)
  }

  public func canSetVirtualMasterVolume (direction: Direction) -> Bool {
    let address = CAProperty.address(
      kAudioHardwareServiceDeviceProperty_VirtualMainVolume, direction.scope
    )
    return CAProperty.isSettable(id, address)
  }

  public func virtualMasterBalance (direction: Direction) -> Float32? {
    let address = CAProperty.address(
      kAudioHardwareServiceDeviceProperty_VirtualMainBalance, direction.scope
    )
    return CAProperty.value(id, address, default: Float32(0))
  }

  @discardableResult
  public func setVirtualMasterBalance (_ balance: Float32, direction: Direction) -> Bool {
    let address = CAProperty.address(
      kAudioHardwareServiceDeviceProperty_VirtualMainBalance, direction.scope
    )
    return CAProperty.setValue(id, address, balance)
  }

  // MARK: - Per-channel volume

  /// `channel` 0 addresses the main element; 1...n address individual channels.
  public func volume (channel: UInt32, direction: Direction) -> Float32? {
    let address = CAProperty.address(kAudioDevicePropertyVolumeScalar, direction.scope, channel)
    return CAProperty.value(id, address, default: Float32(0))
  }

  @discardableResult
  public func setVolume (_ volume: Float32, channel: UInt32, direction: Direction) -> Bool {
    let address = CAProperty.address(kAudioDevicePropertyVolumeScalar, direction.scope, channel)
    return CAProperty.setValue(id, address, volume)
  }

  public func canSetVolume (channel: UInt32, direction: Direction) -> Bool {
    let address = CAProperty.address(kAudioDevicePropertyVolumeScalar, direction.scope, channel)
    return CAProperty.isSettable(id, address)
  }

  public func volumeInDecibels (channel: UInt32, direction: Direction) -> Float32? {
    let address = CAProperty.address(kAudioDevicePropertyVolumeDecibels, direction.scope, channel)
    return CAProperty.value(id, address, default: Float32(0))
  }

  /// CoreAudio's conversion selectors take the input value *in* the output
  /// buffer and overwrite it with the result.
  private func convert (
    _ value: Float32,
    selector: AudioObjectPropertySelector,
    channel: UInt32,
    direction: Direction
  ) -> Float32? {
    var address = CAProperty.address(selector, direction.scope, channel)
    guard CAProperty.has(id, address) else { return nil }

    var converted = value
    var size = UInt32(MemoryLayout<Float32>.size)
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &converted) == noErr else { return nil }
    return converted
  }

  public func decibelsToScalar (volume: Float32, channel: UInt32, direction: Direction) -> Float32? {
    return convert(
      volume,
      selector: kAudioDevicePropertyVolumeDecibelsToScalar,
      channel: channel,
      direction: direction
    )
  }

  public func scalarToDecibels (volume: Float32, channel: UInt32, direction: Direction) -> Float32? {
    return convert(
      volume,
      selector: kAudioDevicePropertyVolumeScalarToDecibels,
      channel: channel,
      direction: direction
    )
  }

  // MARK: - Mute

  public func isMuted (channel: UInt32, direction: Direction) -> Bool? {
    let address = CAProperty.address(kAudioDevicePropertyMute, direction.scope, channel)
    guard let muted: UInt32 = CAProperty.value(id, address, default: 0) else { return nil }
    return muted == 1
  }

  @discardableResult
  public func setMute (_ muted: Bool, channel: UInt32, direction: Direction) -> Bool {
    let address = CAProperty.address(kAudioDevicePropertyMute, direction.scope, channel)
    return CAProperty.setValue(id, address, UInt32(muted ? 1 : 0))
  }

  public func canMuteVirtualMasterChannel (direction: Direction) -> Bool {
    let address = CAProperty.address(kAudioDevicePropertyMute, direction.scope, 0)
    return CAProperty.isSettable(id, address)
  }

  // MARK: - Enumeration

  private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

  public static func allDevices () -> [AudioDevice] {
    let address = CAProperty.address(kAudioHardwarePropertyDevices)
    guard let ids = CAProperty.array(systemObject, address, of: AudioObjectID.self) else { return [] }
    return ids.map { AudioDevice(id: $0) }
  }

  public static func allOutputDevices () -> [AudioDevice] {
    return allDevices().filter { $0.channels(direction: .playback) > 0 }
  }

  public static func allInputDevices () -> [AudioDevice] {
    return allDevices().filter { $0.channels(direction: .recording) > 0 }
  }

  public static func lookup (by uid: String) -> AudioDevice? {
    let address = CAProperty.address(kAudioHardwarePropertyTranslateUIDToDevice)
    guard let deviceID = CAProperty.qualifiedValue(
      systemObject, address,
      qualifier: uid as CFString,
      default: AudioObjectID(kAudioObjectUnknown)
    ) else { return nil }

    return deviceID == kAudioObjectUnknown ? nil : AudioDevice(id: deviceID)
  }

  /// Overload matching AMCoreAudio's by-ID lookup. Returns nil when no live
  /// device carries that ID, so callers can treat it as validation.
  public static func lookup (by id: AudioObjectID) -> AudioDevice? {
    return allDevices().first { $0.id == id }
  }

  // MARK: - Default devices

  private static func defaultDevice (_ selector: AudioObjectPropertySelector) -> AudioDevice? {
    let address = CAProperty.address(selector)
    guard let deviceID: AudioObjectID = CAProperty.value(
      systemObject, address, default: AudioObjectID(kAudioObjectUnknown)
    ), deviceID != kAudioObjectUnknown else { return nil }
    return AudioDevice(id: deviceID)
  }

  public static func defaultOutputDevice () -> AudioDevice? {
    return defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
  }

  public static func defaultInputDevice () -> AudioDevice? {
    return defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
  }

  public static func defaultSystemOutputDevice () -> AudioDevice? {
    return defaultDevice(kAudioHardwarePropertyDefaultSystemOutputDevice)
  }

  @discardableResult
  private func setAsDefault (_ selector: AudioObjectPropertySelector) -> Bool {
    let address = CAProperty.address(selector)
    return CAProperty.setValue(AudioDevice.systemObject, address, id)
  }

  @discardableResult
  public func setAsDefaultOutputDevice () -> Bool {
    return setAsDefault(kAudioHardwarePropertyDefaultOutputDevice)
  }

  @discardableResult
  public func setAsDefaultInputDevice () -> Bool {
    return setAsDefault(kAudioHardwarePropertyDefaultInputDevice)
  }

  @discardableResult
  public func setAsDefaultSystemDevice () -> Bool {
    return setAsDefault(kAudioHardwarePropertyDefaultSystemOutputDevice)
  }
}
