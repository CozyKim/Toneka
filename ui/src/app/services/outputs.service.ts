import { Injectable } from '@angular/core'
import { DataService } from './data.service'

export type DeviceTransportType =
'airPlay' |
'bluetooth' |
'bluetoothLE' |
'builtIn' |
'displayPort' |
'fireWire' |
'hdmi' |
'pci' |
'thunderbolt' |
'usb' |
'aggregate' |
'virtual'

export interface Device {
  id: number
  name: string
  transportType?: DeviceTransportType
}

@Injectable({
  providedIn: 'root'
})
export class OutputsService extends DataService {
  override route = '/outputs'

  getDevices (): Promise<Device[]> {
    return this.request({ method: 'GET', endpoint: '/devices' })
  }

  async getSelectedId (): Promise<number> {
    const { id } = await this.request({ method: 'GET', endpoint: '/selected' })
    return id
  }

  setSelected (id: number) {
    return this.request({ method: 'POST', endpoint: '/selected', data: { id } })
  }

  onDevicesChanged (callback: DevicesChangedEventCallback) {
    this.on('/devices', callback)
  }

  offDevicesChanged (callback: DevicesChangedEventCallback) {
    this.off('/devices', callback)
  }

  onSelectedChanged (callback: SelectedChangedEventCallback) {
    this.on('/selected', callback)
  }

  offSelectedChanged (callback: SelectedChangedEventCallback) {
    this.off('/selected', callback)
  }
}

export type DevicesChangedEventCallback = (devices: Device[]) => void
export type SelectedChangedEventCallback = (data: { id: number }) => void
