import { Injectable } from '@angular/core'
import { EqualizerPreset } from './advanced-equalizer.service'
import { EQUALIZERS_ROUTE, EqualizersService } from './equalizers.service'

export interface BasicEqualizerPresetGains {
  bass: number
  mid: number
  treble: number
}

export type BasicEqualizerBand = keyof BasicEqualizerPresetGains

export interface BasicEqualizerPreset extends EqualizerPreset {
  gains: BasicEqualizerPresetGains
  peakLimiter?: boolean
}

@Injectable({
  providedIn: 'root'
})
export class BasicEqualizerService extends EqualizersService {
  override route = `${EQUALIZERS_ROUTE}/basic`

  getPresets (): Promise<BasicEqualizerPreset[]> {
    return this.request({ method: 'GET', endpoint: '/presets' })
  }

  getSelectedPreset (): Promise<BasicEqualizerPreset> {
    return this.request({ method: 'GET', endpoint: '/presets/selected' })
  }

  createPreset (preset: Omit<BasicEqualizerPreset, 'id' | 'isDefault'>, select = false) {
    return this.request({ method: 'POST', endpoint: '/presets', data: { ...preset, select } as any })
  }

  updatePreset (preset: BasicEqualizerPreset, opts?: { select?: boolean, transition?: boolean }) {
    return this.request({
      method: 'POST',
      endpoint: '/presets',
      data: {
        ...preset,
        select: opts?.select ?? false,
        transition: opts?.transition ?? false
      } as any
    })
  }

  selectPreset (preset: BasicEqualizerPreset) {
    return this.request({ method: 'POST', endpoint: '/presets/select', data: { ...preset } as any })
  }

  deletePreset (preset: BasicEqualizerPreset) {
    return this.request({ method: 'DELETE', endpoint: '/presets', data: { ...preset } as any })
  }

  onPresetsChanged (callback: BasicPresetsChangedEventCallback) {
    this.on('/presets', callback)
  }

  offPresetsChanged (callback: BasicPresetsChangedEventCallback) {
    this.off('/presets', callback)
  }

  onSelectedPresetChanged (callback: BasicSelectedPresetChangedEventCallback) {
    this.on('/presets/selected', callback)
  }

  offSelectedPresetChanged (callback: BasicSelectedPresetChangedEventCallback) {
    this.off('/presets/selected', callback)
  }
}

export type BasicPresetsChangedEventCallback = (presets: BasicEqualizerPreset[]) => void
export type BasicSelectedPresetChangedEventCallback = (preset: BasicEqualizerPreset) => void
