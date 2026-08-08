//
//  SpectrumAnalyser.swift
//  Toneka
//
//  Turns the ring the audio thread fills into one number per equaliser band.
//  Everything here runs on a queue of its own; none of it is realtime.
//

import Foundation
import Accelerate
import EmitterKit

/// One reading of the output: what each band is carrying, and how close the
/// loudest sample in the same window came to full scale.
struct Spectrum {
  let bands: [Double]
  let peak: Double
}

final class SpectrumAnalyser {
  /// The bands are the equaliser's own. The bars are drawn behind its sliders,
  /// and one that did not line up with the handle above it would say nothing
  /// about that handle.
  static let frequencies = AdvancedEqualizer.frequencies

  /// One value per band between nothing and full scale, and the window's peak.
  /// Silent while stopped.
  let volumes = EmitterKit.Event<Spectrum>()

  /// Bins are 11.7Hz apart at 48kHz with this many samples, which leaves the
  /// lowest band a couple of them. Fewer and the bottom of the range collapses
  /// into a single bin that every low note shares.
  private static let window = 4_096

  private static let frameInterval = 1.0 / 30

  /// Where the bars bottom out. Quieter than this is drawn as nothing.
  private static let floorDb = -60.0

  /// Bars rise the moment the sound does and fall behind it. Symmetric
  /// smoothing at this frame rate reads as noise rather than as level.
  private static let fall = 0.35

  private let ring = SpectrumRing.shared
  private let queue = DispatchQueue(label: "Toneka.spectrum", qos: .utility)
  private var timer: DispatchSourceTimer?

  // Everything the transform touches, taken once. A body that runs thirty times
  // a second has no business calling the allocator.
  private let log2n: vDSP_Length
  private let fft: FFTSetup?
  private let hann: UnsafeMutablePointer<Float>
  private let samples: UnsafeMutablePointer<Float>
  private let windowed: UnsafeMutablePointer<Float>
  private let real: UnsafeMutablePointer<Float>
  private let imaginary: UnsafeMutablePointer<Float>
  private let power: UnsafeMutablePointer<Float>

  /// What each band was last drawn at, kept because the fall is gradual.
  private var levels: [Double]

  /// Which bins each band covers, and the rate they were worked out for.
  private var firstBin: [Int]
  private var lastBin: [Int]
  private var mappedSampleRate = 0.0

  init () {
    let n = SpectrumAnalyser.window
    let half = n / 2
    let bands = SpectrumAnalyser.frequencies.count

    log2n = vDSP_Length(log2(Double(n)))
    fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

    hann = .allocate(capacity: n)
    samples = .allocate(capacity: n)
    windowed = .allocate(capacity: n)
    real = .allocate(capacity: half)
    imaginary = .allocate(capacity: half)
    power = .allocate(capacity: half)

    samples.initialize(repeating: 0, count: n)
    windowed.initialize(repeating: 0, count: n)
    real.initialize(repeating: 0, count: half)
    imaginary.initialize(repeating: 0, count: half)
    power.initialize(repeating: 0, count: half)

    // Denormalised: the coefficients peak at one, which is what the scaling
    // further down assumes when it works out where full scale lands.
    hann.initialize(repeating: 0, count: n)
    vDSP_hann_window(hann, vDSP_Length(n), Int32(vDSP_HANN_DENORM))

    levels = Array(repeating: 0, count: bands)
    firstBin = Array(repeating: 0, count: bands)
    lastBin = Array(repeating: 0, count: bands)
  }

  deinit {
    vDSP_destroy_fftsetup(fft)
    for buffer in [ hann, samples, windowed, real, imaginary, power ] {
      buffer.deallocate()
    }
  }

  // MARK: - Running

  var isRunning: Bool { timer != nil }

  /// Nothing exists while stopped — no timer waiting on a condition, no
  /// transform skipped by an if. A window nobody opened costs nothing.
  func start () {
    guard timer == nil, fft != nil else { return }

    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: SpectrumAnalyser.frameInterval)
    timer.setEventHandler { [weak self] in self?.measure() }
    timer.resume()
    self.timer = timer
  }

  func stop () {
    timer?.cancel()
    timer = nil
    // On the queue, so it lands after whichever frame was in flight. Bars left
    // where they stood would be the first thing seen on the way back in.
    queue.async { [weak self] in
      guard let self = self else { return }
      for band in self.levels.indices { self.levels[band] = 0 }
    }
  }

  // MARK: - Measuring

  private func measure () {
    guard let fft = fft else { return }

    let n = SpectrumAnalyser.window
    let half = n / 2
    guard ring.latest(into: samples, count: n) else { return }

    mapBands(for: ring.sampleRate)

    // Taken from the copy already in hand rather than on the audio thread,
    // which does nothing for the analyser but fill the ring. The window is what
    // left for the device, after the equaliser and after the volume, so a
    // ceiling reached here is a ceiling reached there.
    var peak: Float = 0
    vDSP_maxmgv(samples, 1, &peak, vDSP_Length(n))

    vDSP_vmul(samples, 1, hann, 1, windowed, 1, vDSP_Length(n))

    // A real signal packed as half as many complex numbers, which is the form
    // the real transform reads and writes in place.
    var split = DSPSplitComplex(realp: real, imagp: imaginary)
    windowed.withMemoryRebound(to: DSPComplex.self, capacity: half) { packed in
      vDSP_ctoz(packed, 2, &split, 1, vDSP_Length(half))
    }
    vDSP_fft_zrip(fft, &split, 1, log2n, FFTDirection(FFT_FORWARD))
    vDSP_zvmags(&split, 1, power, 1, vDSP_Length(half))

    // The real transform returns twice the mathematical one and this window
    // passes half the amplitude through, so a sine at full scale arrives here
    // as a quarter of the sample count times two. Undoing that puts full scale
    // at zero decibels.
    let scale = 2 / Double(n)
    let floorDb = SpectrumAnalyser.floorDb

    for band in levels.indices {
      let first = firstBin[band]
      let last = lastBin[band]

      var energy: Float = 0
      if first <= last {
        vDSP_sve(power + first, 1, &energy, vDSP_Length(last - first + 1))
      }

      // The root of the energy across the band, not the sum of its magnitudes:
      // a band spans two bins at the bottom of the range and nearly two
      // thousand at the top, and adding magnitudes would make the reading
      // follow that count rather than the sound.
      let amplitude = Double(energy).squareRoot() * scale
      let db = 20 * log10(max(amplitude, 1e-9))
      let value = min(max((db - floorDb) / -floorDb, 0), 1)

      levels[band] = value > levels[band]
        ? value
        : levels[band] + (value - levels[band]) * SpectrumAnalyser.fall
    }

    volumes.emit(Spectrum(bands: levels, peak: Double(peak)))
  }

  /// Which bins fall inside each band. The edges are the geometric means
  /// between neighbouring centres, so a band covers the octave around its own
  /// frequency rather than a slice of a linear axis; the outer two are carried
  /// the same distance past the ends as their neighbours are from them.
  private func mapBands (for sampleRate: Double) {
    guard sampleRate > 0, sampleRate != mappedSampleRate else { return }
    mappedSampleRate = sampleRate

    let centres = SpectrumAnalyser.frequencies
    let width = sampleRate / Double(SpectrumAnalyser.window)
    let highest = SpectrumAnalyser.window / 2 - 1

    for band in centres.indices {
      let below = band > 0
        ? centres[band - 1]
        : centres[0] * centres[0] / centres[1]
      let above = band < centres.count - 1
        ? centres[band + 1]
        : centres[band] * centres[band] / centres[band - 1]

      // Bin zero is left out: the real transform keeps the Nyquist term in its
      // imaginary part, so the magnitude there is not the magnitude of one
      // frequency. Nothing as low as the first band's edge reaches it anyway.
      firstBin[band] = min(max(Int(((centres[band] * below).squareRoot() / width).rounded(.up)), 1), highest)
      lastBin[band] = min(Int(((centres[band] * above).squareRoot() / width).rounded(.down)), highest)
    }
  }
}
