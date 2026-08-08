//
//  TapEngine.swift
//  Toneka
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
  // Told apart from `cycles` so that a spectrum showing nothing can be blamed
  // on the analyser rather than on the audio never reaching it.
  var spectrumWrites = 0

  /// Where the rendered channels are mixed down to mono on their way to the
  /// analyser. Allocated once and owned here, because the mixing happens on the
  /// realtime thread and that thread must never reach the allocator.
  let mono: UnsafeMutablePointer<Float>
  private let monoCapacity: Int

  init (frameCapacity: Int) {
    monoCapacity = frameCapacity
    mono = .allocate(capacity: frameCapacity)
    mono.initialize(repeating: 0, count: frameCapacity)
  }

  deinit {
    mono.deinitialize(count: monoCapacity)
    mono.deallocate()
  }
}

final class TapEngine {
  private let tap: ProcessTap
  private let aggregate: AggregateDevice
  private let engine = AVAudioEngine()
  private let handoff = TapInputHandoff(frameCapacity: Int(TapEngine.maximumFrames))

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

    // The aggregate's rate rather than the tap's. Manual rendering hands frames
    // straight through without resampling them, so what leaves the graph is
    // clocked by the device the IOProc drives, and the two do not have to agree.
    //
    // Everything downstream that turns a frequency into a number of samples
    // needs this one: the equaliser to place its filters and the analyser to
    // place its bins. Asked for once and shared, because two answers to the
    // same question would put the bars somewhere the bands are not.
    //
    // The tap's rate when the device will not say. Filters landing away from
    // their labels is a graph that still passes audio; no graph at all is
    // silence.
    let deviceRate = CAProperty.value(
      aggregate.objectID,
      CAProperty.address(kAudioDevicePropertyNominalSampleRate),
      default: Double(0)
    ) ?? 0
    let sampleRate = deviceRate > 0 ? deviceRate : tap.format.mSampleRate
    SpectrumRing.shared.sampleRate = sampleRate

    guard buildGraph(sampleRate: sampleRate) else { return nil }

    // The mixer only holds a volume once it belongs to a running graph.
    volume.postSetup()
  }

  // MARK: - Graph

  /// The channel count is the tap's and the frame count is whatever the IOProc
  /// asks for; only the rate comes from the caller.
  private func buildGraph (sampleRate: Double) -> Bool {
    // The tap vends interleaved Float32 but AVAudioEngine's mixers only accept
    // deinterleaved, so the graph runs in the standard format and we convert
    // at both edges.
    guard let renderFormat = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate,
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
    let ring = SpectrumRing.shared
    var procID: AudioDeviceIOProcID?
    let createStatus = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregate.objectID, nil) {
      _, inputData, _, outputData, _ in
      TapEngine.render(
        input: inputData,
        output: outputData,
        handoff: handoff,
        renderBlock: renderBlock,
        renderBuffer: renderBuffer,
        ring: ring
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
      "peak \(handoff.peak),",
      "\(handoff.spectrumWrites) spectrum writes"
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
    renderBuffer: AVAudioPCMBuffer,
    ring: SpectrumRing
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

    // The analyser wants one signal, and it is gathered here rather than in a
    // pass of its own: the samples are already in registers on their way to the
    // device. Averaged rather than summed, so two channels carrying the same
    // material do not read six decibels louder than either of them.
    let mono = handoff.mono
    let share = 1 / Float(channels)

    for channel in 0 ..< channels {
      let isFirst = channel == 0
      if channel < rendered.count,
         let source = rendered[channel].mData?.assumingMemoryBound(to: Float.self) {
        for frame in 0 ..< frames {
          let value = source[frame]
          targetData[frame * channels + channel] = value
          let magnitude = abs(value)
          if magnitude > handoff.peak { handoff.peak = magnitude }
          let part = value * share
          mono[frame] = isFirst ? part : mono[frame] + part
        }
      } else {
        for frame in 0 ..< frames {
          targetData[frame * channels + channel] = 0
          if isFirst { mono[frame] = 0 }
        }
      }
    }

    ring.write(mono, count: frames)
    handoff.spectrumWrites += 1
  }

  deinit {
    stop()
    engine.stop()
  }
}
