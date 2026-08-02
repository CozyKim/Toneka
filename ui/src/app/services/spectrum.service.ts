import { Injectable } from '@angular/core'
import { DataService } from './data.service'

@Injectable({
  providedIn: 'root'
})
export class SpectrumService extends DataService {
  override route = '/analyzer'

  getFrequencies (): Promise<number[]> {
    return this.request({ method: 'GET', endpoint: '/frequencies' })
  }

  /// The analyser is off until something asks for it, so whatever is showing
  /// the bars is what turns it on and off again.
  setEnabled (enabled: boolean) {
    return this.request({ method: 'POST', endpoint: '/enabled', data: { enabled } })
  }

  onVolumes (callback: VolumesEventCallback) {
    this.on('/volumes', callback)
  }

  offVolumes (callback: VolumesEventCallback) {
    this.off('/volumes', callback)
  }
}

/// One reading of the output, taken from a single window of it.
export interface Spectrum {
  /// One value per band between nothing and full scale, in the order the band
  /// frequencies are given in.
  bands: number[]
  /// The loudest sample in the same window. At or above one it is at the
  /// ceiling and what reaches the device is being cut off.
  peak: number
}

export type VolumesEventCallback = (spectrum: Spectrum) => void
