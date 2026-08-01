import { Injectable } from '@angular/core'
import { DataService } from './data.service'

// The native side spells these with a capital, and rejects anything that is
// not one of its own raw values.
export const EqualizersTypes = [
  'Basic',
  'Advanced'
] as const
export type EqualizerType = typeof EqualizersTypes[number]

/// Named rather than composed from the parent's field: a subclass writing
/// `${this.route}/advanced` reads a property that has not been initialised yet.
export const EQUALIZERS_ROUTE = '/effects/equalizers'

@Injectable({
  providedIn: 'root'
})
export class EqualizersService extends DataService {
  override route = EQUALIZERS_ROUTE

  async getEnabled (): Promise<boolean> {
    const { enabled } = await this.request({ method: 'GET', endpoint: '/enabled' })
    return enabled
  }

  setEnabled (enabled: boolean) {
    return this.request({ method: 'POST', endpoint: '/enabled', data: { enabled } })
  }

  async getType (): Promise<EqualizerType> {
    const { type } = await this.request({ method: 'GET', endpoint: '/type' })
    return type
  }

  setType (type: EqualizerType) {
    return this.request({ method: 'POST', endpoint: '/type', data: { type } })
  }
}
