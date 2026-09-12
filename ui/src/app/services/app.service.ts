import { EventEmitter, Injectable } from '@angular/core'
import { AppComponent } from '../app.component'
import { ConstantsService } from './constants.service'
import { DataService } from './data.service'
import { UIService } from './ui.service'

export interface Info {
  name: string
  model: string
  version: string
  isOpenSource: boolean
  driverVersion?: string
}

export const SystemSounds = [
  'Basso',
  'Blow',
  'Bottle',
  'From',
  'Funk',
  'Glass',
  'Hero',
  'Morse',
  'Ping',
  'Pop',
  'Purr',
  'Sosumi',
  'Submarine',
  'Tink'
] as const
export type SystemSound = typeof SystemSounds[number]

@Injectable({
  providedIn: 'root'
})
export class ApplicationService extends DataService {
  enabled?: boolean
  ref?: AppComponent
  info?: Info

  constructor (
    public CONST: ConstantsService,
    public ui: UIService
  ) {
    super()
    this.on('/error', ({ error }) => {
      console.error('native error', error)
    })
    this.sync()
  }

  async sync () {
    const [ enabled ] = await Promise.all([
      this.getEnabled()
    ])
    this.enabled = enabled
  }

  async getInfo (): Promise<Info> {
    let info = this.info
    if (!info) {
      info = await this.request({ method: 'GET', endpoint: '/info' }) as Info
      // < v1.0.0 didn't return isOpenSource property so need to set it
      info.isOpenSource ??= true
      this.info = info
    }
    return info
  }

  quit () {
    return this.request({ method: 'GET', endpoint: '/quit' })
  }

  openFAQ () {
    return this.request({ method: 'GET', endpoint: '/faq' })
  }

  openURL (url: URL) {
    return this.request({ method: 'POST', endpoint: '/open-url', data: { url: url.href } })
  }

  uninstall () {
    return this.openURL(new URL('https://github.com/CozyKim/Toneka#uninstall'))
  }

  lastHaptic?: Date
  haptic () {
    if (!this.lastHaptic || new Date().getTime() - this.lastHaptic.getTime() > 1000) {
      this.lastHaptic = new Date()
      return this.request({ method: 'GET', endpoint: '/haptic' })
    }
    return undefined
  }

  update () {
    return this.request({ method: 'GET', endpoint: '/update' })
  }

  openLog () {
    return this.request({ method: 'GET', endpoint: '/log/open' })
  }

  reportError (message: string) {
    return this.request({ method: 'POST', endpoint: '/log/error', data: { message } })
  }

  async getEnabled (): Promise<boolean> {
    const { enabled } = await this.request({ method: 'GET', endpoint: '/enabled' })
    this.enabled = enabled
    return enabled
  }

  setEnabled (enabled: boolean) {
    this.enabled = enabled
    return this.request({ method: 'POST', endpoint: '/enabled', data: { enabled } })
  }

  async getBundleIcon (bundleId: string): Promise<string> {
    const resp = await this.request({ method: 'GET', endpoint: '/bundle-icon', data: { bundleId } })
    return resp?.base64
  }

  playAlertSound () {
    return this.request({ method: 'GET', endpoint: '/alert-sound' })
  }

  playSystemSound (name: SystemSound) {
    return this.request({ method: 'POST', endpoint: '/system-sound', data: { name } })
  }
}
