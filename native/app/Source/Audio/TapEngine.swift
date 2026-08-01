//
//  TapEngine.swift
//  eqMac
//
//  Audio pipeline built on a Core Audio process tap instead of a HAL driver.
//
//  One aggregate device carries both the tap (input) and the real output
//  device, so a single IOProc drives capture and playback off the same clock.
//  The effect graph runs inside AVAudioEngine's manual rendering mode, which
//  lets the existing AVAudioUnitEQ / AVAudioMixerNode chain stay as it is.
//
//      IOProc ──► source node ──► equalizer ──► volume mixer ──► main mixer
//         ▲                                                          │
//         └──────────────── rendered frames ◄────────────────────────┘
//

import Foundation
import AVFoundation
import CoreAudio

/// Handoff point between the IOProc and the source node. Both run on the
/// realtime thread within the same IOProc cycle, so a plain reference is
/// enough — the pointer is only valid for the duration of one callback.
private final class TapInputHandoff {
  var bufferList: UnsafePointer<AudioBufferList>?

  // Counters for diagnosing a silent pipeline: a stopped engine that saw no
  // cycles points at the IOProc, one with cycles but no signal at the tap.
  var cycles = 0
  var renderFailures = 0
  var peak: Float = 0
}

final class TapEngine {
  private let tap: ProcessTap
  private let aggregate: AggregateDevice
  private let engine = AVAudioEngine()
  private let handoff = TapInputHandoff()

  private var sourceNode: AVAudioSourceNode?
  private var procID: AudioDeviceIOProcID?
  private var renderBlock: AVAudioEngineManualRenderingBlock?
  private var renderBuffer: AVAudioPCMBuffer?
  private var running = false

  let equalizers: Equalizers
  let volume: Volume
  let outputDevice: AudioDevice

  private static let maximumFrames: AVAudioFrameCount = 4096

  init? (outputDevice: AudioDevice, equalizers: Equalizers, volume: Volume) {
    guard let outputUID = outputDevice.uid else {
      Console.log("Output device has no UID, cannot build tap pipeline")
      return nil
    }

    // Excluding ourselves matters: we render back to the same device we tap,
    // and without this the output would be captured again.
    var excluded: [AudioObjectID] = []
    if let ownProcess = ProcessTap.currentProcessObject() {
      excluded.append(ownProcess)
    }

    guard let tap = ProcessTap(deviceUID: outputUID, excludedProcesses: excluded) else {
      return nil
    }
    guard let aggregate = AggregateDevice(tapUID: tap.uid, outputDeviceUID: outputUID) else {
      return nil
    }

    self.tap = tap
    self.aggregate = aggregate
    self.equalizers = equalizers
    self.volume = volume
    self.outputDevice = outputDevice

    guard buildGraph() else { return nil }
  }

  // MARK: - Graph

  private func buildGraph () -> Bool {
    // The tap vends interleaved Float32 but AVAudioEngine's mixers only accept
    // deinterleaved, so the graph runs in the standard format and we convert
    // at both edges.
    guard let renderFormat = AVAudioFormat(
      standardFormatWithSampleRate: tap.format.mSampleRate,
      channels: tap.format.mChannelsPerFrame
    ) else {
      Console.log("Could not derive render format from tap")
      return false
    }

    guard let equalizer = equalizers.active?.eq else {
      Console.log("No active equalizer to attach")
      return false
    }

    let handoff = self.handoff
    let sourceNode = AVAudioSourceNode(format: renderFormat) { _, _, frameCount, audioBufferList in
      TapEngine.deinterleave(from: handoff.bufferList, into: audioBufferList, frames: frameCount)
      return noErr
    }
    self.sourceNode = sourceNode

    engine.attach(sourceNode)
    engine.attach(equalizer)
    engine.attach(volume.mixer)

    engine.connect(sourceNode, to: equalizer, format: renderFormat)
    engine.connect(equalizer, to: volume.mixer, format: renderFormat)
    engine.connect(volume.mixer, to: engine.mainMixerNode, format: renderFormat)

    do {
      try engine.enableManualRenderingMode(
        .realtime, format: renderFormat, maximumFrameCount: TapEngine.maximumFrames
      )
      try engine.start()
    } catch {
      Console.log("Failed to start manual rendering engine: \(error)")
      return false
    }

    renderBlock = engine.manualRenderingBlock
    renderBuffer = AVAudioPCMBuffer(
      pcmFormat: engine.manualRenderingFormat, frameCapacity: TapEngine.maximumFrames
    )

    guard renderBuffer != nil else {
      Console.log("Could not allocate render buffer")
      return false
    }

    return true
  }

  // MARK: - Running

  @discardableResult
  func start () -> Bool {
    guard !running else { return true }
    guard let renderBlock = renderBlock, let renderBuffer = renderBuffer else { return false }

    let handoff = self.handoff
    var procID: AudioDeviceIOProcID?
    let createStatus = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate.objectID, nil) {
      _, inputData, _, outputData, _ in
      TapEngine.render(
        input: inputData,
        output: outputData,
        handoff: handoff,
        renderBlock: renderBlock,
        renderBuffer: renderBuffer
      )
    }

    guard createStatus == noErr, let createdProcID = procID else {
      Console.log("Failed to create IOProc: \(createStatus)")
      return false
    }

    let startStatus = AudioDeviceStart(aggregate.objectID, createdProcID)
    guard startStatus == noErr else {
      AudioDeviceDestroyIOProcID(aggregate.objectID, createdProcID)
      Console.log("Failed to start aggregate device: \(startStatus)")
      return false
    }

    self.procID = createdProcID
    running = true
    return true
  }

  func stop () {
    guard let procID = procID else { return }
    AudioDeviceStop(aggregate.objectID, procID)
    AudioDeviceDestroyIOProcID(aggregate.objectID, procID)
    self.procID = nil
    running = false

    Console.log(
      "Tap pipeline stopped after \(handoff.cycles) cycles,",
      "\(handoff.renderFailures) render failures,",
      "peak \(handoff.peak)"
    )
  }

  // MARK: - Realtime

  /// Splits the tap's interleaved frames into the graph's per-channel buffers.
  private static func deinterleave (
    from source: UnsafePointer<AudioBufferList>?,
    into destination: UnsafeMutablePointer<AudioBufferList>,
    frames: AVAudioFrameCount
  ) {
    let output = UnsafeMutableAudioBufferListPointer(destination)
    let wanted = Int(frames)

    func silence () {
      for buffer in output {
        if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
      }
    }

    guard let source = source else { return silence() }
    let input = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source))
    guard let packed = input.first, let packedData = packed.mData else { return silence() }

    let channels = max(Int(packed.mNumberChannels), 1)
    let available = Int(packed.mDataByteSize) / MemoryLayout<Float>.size / channels
    let usable = min(available, wanted)
    let samples = packedData.assumingMemoryBound(to: Float.self)

    for channel in 0 ..< output.count {
      guard let target = output[channel].mData?.assumingMemoryBound(to: Float.self) else { continue }
      if channel < channels {
        for frame in 0 ..< usable {
          target[frame] = samples[frame * channels + channel]
        }
      } else {
        for frame in 0 ..< usable { target[frame] = 0 }
      }
      if wanted > usable {
        for frame in usable ..< wanted { target[frame] = 0 }
      }
    }
  }

  /// Runs one IOProc cycle: hand the tapped frames to the graph, render, and
  /// interleave the result back into the device's output buffer.
  private static func render (
    input: UnsafePointer<AudioBufferList>,
    output: UnsafeMutablePointer<AudioBufferList>,
    handoff: TapInputHandoff,
    renderBlock: @escaping AVAudioEngineManualRenderingBlock,
    renderBuffer: AVAudioPCMBuffer
  ) {
    let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
    guard let target = outputBuffers.first,
          let targetData = target.mData?.assumingMemoryBound(to: Float.self) else { return }

    let channels = max(Int(target.mNumberChannels), 1)
    let frames = Int(target.mDataByteSize) / MemoryLayout<Float>.size / channels
    guard frames > 0, frames <= Int(maximumFrames) else { return }

    handoff.bufferList = input
    defer { handoff.bufferList = nil }

    renderBuffer.frameLength = AVAudioFrameCount(frames)
    var status: OSStatus = noErr
    let result = renderBlock(AVAudioFrameCount(frames), renderBuffer.mutableAudioBufferList, &status)

    handoff.cycles += 1

    guard result == .success else {
      handoff.renderFailures += 1
      memset(targetData, 0, Int(target.mDataByteSize))
      return
    }

    let rendered = UnsafeMutableAudioBufferListPointer(renderBuffer.mutableAudioBufferList)
    for channel in 0 ..< channels {
      if channel < rendered.count,
         let source = rendered[channel].mData?.assumingMemoryBound(to: Float.self) {
        for frame in 0 ..< frames {
          let value = source[frame]
          targetData[frame * channels + channel] = value
          let magnitude = abs(value)
          if magnitude > handoff.peak { handoff.peak = magnitude }
        }
      } else {
        for frame in 0 ..< frames { targetData[frame * channels + channel] = 0 }
      }
    }
  }

  deinit {
    stop()
    engine.stop()
  }
}
