//
//  SpectrumRing.swift
//  eqMac
//
//  The audio the analyser looks at, and the only thing the realtime thread
//  does on its behalf.
//

import Foundation

/// A fixed ring the audio thread writes into and the analyser reads from.
///
/// One writer and one reader, and neither waits for the other: the writer only
/// ever stores samples and advances an index, and a reader that catches a stale
/// index simply gets audio a fraction of a frame older than it could have. For
/// something being drawn thirty times a second that is invisible, and it is
/// what keeps the audio thread free of locks.
///
/// `written` and `sampleRate` are read on the analysis queue while the audio
/// thread writes them, without a barrier between the two. An aligned word store
/// does not tear on the architectures this ships to, so a reader sees either
/// the old value or the new one and both are usable.
final class SpectrumRing {
  /// One ring for the whole application rather than one per pipeline. The
  /// pipeline is torn down and rebuilt whenever the output device or its sample
  /// rate changes, while the analyser outlives all of it — handing the analyser
  /// a reference that the main thread reassigns underneath it would be a race
  /// no amount of care on the reading side could fix.
  static let shared = SpectrumRing()

  /// Big enough to hold several render cycles at the largest frame count, so a
  /// reader asking for a whole FFT window never overtakes the writer.
  static let capacity = 16_384

  private let storage: UnsafeMutablePointer<Float>
  /// Total samples ever written. Wrapped only when indexing.
  private var written: Int = 0

  /// The rate the samples were produced at. It travels with them because the
  /// analyser has no way to ask the pipeline anything, and a bin index means
  /// nothing without it.
  var sampleRate: Double = 48_000

  init () {
    storage = .allocate(capacity: SpectrumRing.capacity)
    storage.initialize(repeating: 0, count: SpectrumRing.capacity)
  }

  deinit {
    storage.deinitialize(count: SpectrumRing.capacity)
    storage.deallocate()
  }

  /// Called on the audio thread. Allocates nothing, takes no lock, logs nothing.
  func write (_ samples: UnsafePointer<Float>, count: Int) {
    guard count > 0, count <= SpectrumRing.capacity else { return }
    var index = written % SpectrumRing.capacity
    for offset in 0 ..< count {
      storage[index] = samples[offset]
      index += 1
      if index == SpectrumRing.capacity { index = 0 }
    }
    written &+= count
  }

  /// Copies the most recent `count` samples in order. False when the ring has
  /// not filled that far yet.
  func latest (into destination: UnsafeMutablePointer<Float>, count: Int) -> Bool {
    let total = written
    guard count <= SpectrumRing.capacity, total >= count else { return false }
    var index = (total - count) % SpectrumRing.capacity
    for offset in 0 ..< count {
      destination[offset] = storage[index]
      index += 1
      if index == SpectrumRing.capacity { index = 0 }
    }
    return true
  }
}
