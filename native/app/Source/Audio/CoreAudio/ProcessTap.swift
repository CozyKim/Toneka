//
//  ProcessTap.swift
//  Toneka
//
//  Owns the lifetime of a Core Audio process tap (macOS 14.2+).
//
//  A tap captures what other processes send to an output device without a HAL
//  driver in the path. With `.mutedWhenTapped` the original signal is silenced,
//  so whoever owns the tap becomes responsible for rendering the audio.
//

import Foundation
import CoreAudio

final class ProcessTap {
  let objectID: AudioObjectID
  let uid: String
  let format: AudioStreamBasicDescription

  /// - Parameters:
  ///   - deviceUID: restrict the tap to a single output device.
  ///   - excludedProcesses: process objects whose audio must not be captured.
  ///     Passing our own process object is what prevents a feedback loop,
  ///     since we render back to the very device we are tapping.
  ///   - muted: whether the original signal keeps playing alongside ours.
  init? (deviceUID: String, excludedProcesses: [AudioObjectID], muted: Bool = true) {
    let description = CATapDescription()
    description.name = "Toneka System Capture"
    description.isPrivate = true
    description.isMixdown = true
    description.isMono = false
    description.isExclusive = true            // `processes` is an exclude list
    description.processes = excludedProcesses
    description.muteBehavior = muted ? .mutedWhenTapped : .unmuted
    description.deviceUID = deviceUID

    var objectID = AudioObjectID(kAudioObjectUnknown)
    let status = AudioHardwareCreateProcessTap(description, &objectID)
    guard status == noErr, objectID != kAudioObjectUnknown else {
      Console.log("Failed to create process tap: \(status)")
      return nil
    }

    guard let uid = CAProperty.string(
      objectID, CAProperty.address(kAudioTapPropertyUID)
    ) else {
      AudioHardwareDestroyProcessTap(objectID)
      Console.log("Failed to read process tap UID")
      return nil
    }

    guard let format = CAProperty.value(
      objectID,
      CAProperty.address(kAudioTapPropertyFormat),
      default: AudioStreamBasicDescription()
    ), format.mSampleRate > 0 else {
      AudioHardwareDestroyProcessTap(objectID)
      Console.log("Failed to read process tap format")
      return nil
    }

    self.objectID = objectID
    self.uid = uid
    self.format = format
  }

  /// The process object for this app, used to exclude ourselves from a tap.
  /// Returns nil until the process has been seen by CoreAudio.
  static func currentProcessObject () -> AudioObjectID? {
    let address = CAProperty.address(kAudioHardwarePropertyTranslatePIDToProcessObject)
    guard let objectID = CAProperty.qualifiedValue(
      AudioObjectID(kAudioObjectSystemObject), address,
      qualifier: getpid(),
      default: AudioObjectID(kAudioObjectUnknown)
    ), objectID != kAudioObjectUnknown else { return nil }
    return objectID
  }

  deinit {
    let status = AudioHardwareDestroyProcessTap(objectID)
    if status != noErr {
      Console.log("Failed to destroy process tap \(objectID): \(status)")
    }
  }
}
