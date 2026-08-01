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

/// One value per band between nothing and full scale, in the order the band
/// frequencies are given in.
export type VolumesEventCallback = (volumes: number[]) => void
