//
//  AggregateDevice.swift
//  eqMac
//
//  Owns the lifetime of a private aggregate device that pairs a process tap
//  (input) with a real output device.
//
//  Keeping both sides in one aggregate means one IOProc drives both, so the
//  capture and the playback share a clock. That is what removes the need for
//  the sample-rate drift correction the driver-based pipeline required.
//

import Foundation
import CoreAudio

final class AggregateDevice {
  /// Identifies eqMac's own aggregate so it can be filtered out of the device
  /// lists we show to the user.
  static let uid = "com.bitgapp.eqmac.aggregate"

  let objectID: AudioObjectID

  init? (tapUID: String, outputDeviceUID: String) {
    let composition: [String: Any] = [
      kAudioAggregateDeviceNameKey: "eqMac",
      kAudioAggregateDeviceUIDKey: AggregateDevice.uid,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
      kAudioAggregateDeviceTapAutoStartKey: true,
      kAudioAggregateDeviceMainSubDeviceKey: outputDeviceUID,
      kAudioAggregateDeviceSubDeviceListKey: [
        [kAudioSubDeviceUIDKey: outputDeviceUID]
      ],
      kAudioAggregateDeviceTapListKey: [
        [
          kAudioSubTapUIDKey: tapUID,
          kAudioSubTapDriftCompensationKey: true
        ]
      ]
    ]

    var objectID = AudioObjectID(kAudioObjectUnknown)
    let status = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &objectID)
    guard status == noErr, objectID != kAudioObjectUnknown else {
      Console.log("Failed to create aggregate device: \(status)")
      return nil
    }

    self.objectID = objectID
  }

  var device: AudioDevice {
    return AudioDevice(id: objectID)
  }

  deinit {
    let status = AudioHardwareDestroyAggregateDevice(objectID)
    if status != noErr {
      Console.log("Failed to destroy aggregate device \(objectID): \(status)")
    }
  }
}
