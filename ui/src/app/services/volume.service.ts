import { Injectable } from '@angular/core'
import { DataService } from './data.service'

@Injectable({ providedIn: 'root' })
export class VolumeService extends DataService {
  override route = '/volume'

  async getGain (): Promise<number> {
    const { gain } = await this.request({ method: 'GET', endpoint: '/gain' })
    return gain
  }

  setGain (gain: number) {
    return this.request({ method: 'POST', endpoint: '/gain', data: { gain } })
  }

  async getMuted (): Promise<boolean> {
    const { muted } = await this.request({ method: 'GET', endpoint: '/muted' })
    return muted
  }

  setMuted (muted: boolean) {
    return this.request({ method: 'POST', endpoint: '/muted', data: { muted } })
  }

  async getBalance (): Promise<number> {
    const { balance } = await this.request({ method: 'GET', endpoint: '/balance' })
    return balance
  }

  setBalance (balance: number) {
    return this.request({ method: 'POST', endpoint: '/balance', data: { balance } })
  }

  async getBoostEnabled (): Promise<boolean> {
    const { enabled } = await this.request({ method: 'GET', endpoint: '/gain/boost/enabled' })
    return enabled
  }

  setBoostEnabled (enabled: boolean) {
    return this.request({ method: 'POST', endpoint: '/gain/boost/enabled', data: { enabled } })
  }

  // Gain and the boost flag are the two the native side pushes back. It moves
  // gain on its own whenever the volume keys are pressed, so a slider that
  // only ever read it once would sit still while the sound changed.
  onGainChanged (callback: GainChangedEventCallback) { this.on('/gain', callback) }
  offGainChanged (callback: GainChangedEventCallback) { this.off('/gain', callback) }

  onBoostEnabledChanged (callback: BoostEnabledChangedEventCallback) { this.on('/gain/boost/enabled', callback) }
  offBoostEnabledChanged (callback: BoostEnabledChangedEventCallback) { this.off('/gain/boost/enabled', callback) }
}

export type GainChangedEventCallback = (data: { gain: number }) => void
export type BoostEnabledChangedEventCallback = (data: { enabled: boolean }) => void
