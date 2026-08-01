import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core'

import { DropdownComponent } from '../../../lib/dropdown/dropdown.component'
import { IconName } from '../../../lib/icon/icons'
import { Device, OutputsService } from '../../services/outputs.service'

/// The dropdown draws an icon when the item carries one, so the transport a
/// device is attached by is shown rather than spelled out.
interface DeviceItem extends Device {
  icon: IconName
}

@Component({
  selector: 'eqm-output',
  standalone: true,
  imports: [ DropdownComponent ],
  template: `
    <span class="label">출력</span>
    <eqm-dropdown
      class="field"
      labelParam="name"
      [items]="devices()"
      [selectedItem]="selected()"
      (selectedItemChange)="select($event)">
    </eqm-dropdown>
  `,
  styles: [`
    :host {
      flex: 0 0 auto;
      display: flex;
      align-items: center;
      gap: var(--space-3);
      padding: var(--space-2) var(--space-3);
      border-bottom: 1px solid var(--chrome-edge);
      box-shadow: 0 1px 0 var(--chrome-lip);
    }

    .label {
      flex: 0 0 38px;
      font-size: 11px;
      color: var(--text-secondary);
    }

    .field { flex: 1; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class OutputComponent implements OnInit {
  private readonly outputs = inject(OutputsService)

  readonly devices = signal<DeviceItem[]>([])
  readonly selected = signal<DeviceItem | undefined>(undefined)

  async ngOnInit () {
    // The native side pushes a new list when a device is plugged in or
    // removed, so the list is not read once and kept.
    this.outputs.onDevicesChanged(devices => {
      this.devices.set(devices.map(device => this.decorate(device)))
      void this.syncSelection()
    })
    this.outputs.onSelectedChanged(() => { void this.syncSelection() })

    this.devices.set((await this.outputs.getDevices()).map(device => this.decorate(device)))
    await this.syncSelection()
  }

  private decorate (device: Device): DeviceItem {
    return { ...device, icon: iconFor(device) }
  }

  private async syncSelection () {
    const id = await this.outputs.getSelectedId()
    this.selected.set(this.devices().find(device => device.id === id))
  }

  select (device: DeviceItem) {
    this.selected.set(device)
    void this.outputs.setSelected(device.id)
  }
}

function iconFor (device: Device): IconName {
  switch (device.transportType) {
    case 'airPlay': return 'airplay'
    case 'bluetooth':
    case 'bluetoothLE': return 'bluetooth'
    // Built-in covers both the speakers and the headphone jack, and only the
    // name tells them apart.
    case 'builtIn': return device.name === 'Headphones' ? 'headphones' : 'speaker'
    case 'displayPort': return 'displayport'
    case 'fireWire': return 'firewire'
    case 'hdmi': return 'hdmi'
    case 'pci': return 'pci'
    case 'thunderbolt': return 'thunderbolt'
    case 'usb': return 'usb'
    case 'aggregate': return 'aggregate'
    default: return 'speaker'
  }
}
