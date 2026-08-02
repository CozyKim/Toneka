import { Injectable } from '@angular/core'
import { EQUALIZERS_ROUTE, EqualizersService } from './equalizers.service'

export interface EqualizerPreset {
  id: string
  name: string
  isDefault: boolean
  /// Shaped differently per equaliser -- ten bands here, three named gains on
  /// the basic one -- and left opaque so that what is common to both can be
  /// handled without knowing which arrived.
  gains: unknown
}

export interface AdvancedEqualizerPreset extends EqualizerPreset {
  gains: {
    bands: number[]
    global: number
  }
}

@Injectable({
  providedIn: 'root'
})
export class AdvancedEqualizerService extends EqualizersService {
  override route = `${EQUALIZERS_ROUTE}/advanced`

  getPresets (): Promise<AdvancedEqualizerPreset[]> {
    return this.request({ method: 'GET', endpoint: '/presets' })
  }

  getSelectedPreset (): Promise<AdvancedEqualizerPreset> {
    return this.request({ method: 'GET', endpoint: '/presets/selected' })
  }

  createPreset (preset: Omit<AdvancedEqualizerPreset, 'id' | 'isDefault'>, select = false) {
    return this.request({ method: 'POST', endpoint: '/presets', data: { ...preset, select } })
  }

  updatePreset (preset: AdvancedEqualizerPreset, opts?: { select?: boolean, transition?: boolean }) {
    return this.request({
      method: 'POST',
      endpoint: '/presets',
      data: {
        ...preset,
        select: opts?.select ?? false,
        transition: opts?.transition ?? false
      }
    })
  }

  selectPreset (preset: AdvancedEqualizerPreset) {
    return this.request({ method: 'POST', endpoint: '/presets/select', data: { ...preset } })
  }

  deletePreset (preset: AdvancedEqualizerPreset) {
    return this.request({ method: 'DELETE', endpoint: '/presets', data: { ...preset } })
  }

  importPresets () {
    return this.request({ method: 'GET', endpoint: '/presets/import' })
  }

  exportPresets () {
    return this.request({ method: 'GET', endpoint: '/presets/export' })
  }

  async getShowDefaultPresets (): Promise<boolean> {
    const { show } = await this.request({ method: 'GET', endpoint: '/settings/show-default-presets' })
    return show
  }

  setShowDefaultPresets (show: boolean) {
    return this.request({ method: 'POST', endpoint: '/settings/show-default-presets', data: { show } })
  }

  onPresetsChanged (callback: PresetsChangedEventCallback) {
    this.on('/presets', callback)
  }

  offPresetsChanged (callback: PresetsChangedEventCallback) {
    this.off('/presets', callback)
  }

  onSelectedPresetChanged (callback: SelectedPresetChangedEventCallback) {
    this.on('/presets/selected', callback)
  }

  offSelectedPresetChanged (callback: SelectedPresetChangedEventCallback) {
    this.off('/presets/selected', callback)
  }
}

export type PresetsChangedEventCallback = (presets: AdvancedEqualizerPreset[]) => void
export type SelectedPresetChangedEventCallback = (preset: AdvancedEqualizerPreset) => void
