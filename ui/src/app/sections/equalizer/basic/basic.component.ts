import {
  ChangeDetectionStrategy,
  Component,
  HostListener,
  OnDestroy,
  OnInit,
  inject,
  signal
} from '@angular/core'

import { KnobComponent } from '../../../../lib/knob/knob.component'
import {
  BasicEqualizerBand,
  BasicEqualizerPreset,
  BasicEqualizerPresetGains,
  BasicEqualizerService
} from '../../../services/basic-equalizer.service'
import { UIService } from '../../../services/ui.service'

/// The same range the ten-band equaliser and the native presets are written in.
const LIMIT = 24

const SEND_INTERVAL = 1000 / 30

@Component({
  selector: 'eqm-basic-equalizer',
  standalone: true,
  imports: [ KnobComponent ],
  template: `
    @for (band of bands; track band.key) {
      <div class="unit">
        <eqm-knob
          size="large"
          [controlStyle]="controlStyle"
          [min]="-limit" [max]="limit"
          [stickToMiddle]="true"
          [value]="gains()[band.key]"
          (userChangedValue)="change(band.key, $event.value)">
        </eqm-knob>
        <span class="name">{{ band.name }}</span>
      </div>
    }
  `,
  styles: [`
    :host {
      display: flex;
      align-items: center;
      justify-content: space-around;
      height: 100%;
    }

    .unit {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: var(--space-2);
    }

    .name { font-size: 11px; color: var(--text-secondary); }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class BasicEqualizerComponent implements OnInit, OnDestroy {
  private readonly basic = inject(BasicEqualizerService)
  private readonly ui = inject(UIService)

  readonly limit = LIMIT
  readonly bands = [
    { key: 'bass' as BasicEqualizerBand, name: '저음' },
    { key: 'mid' as BasicEqualizerBand, name: '중음' },
    { key: 'treble' as BasicEqualizerBand, name: '고음' }
  ]

  readonly gains = signal<BasicEqualizerPresetGains>({ bass: 0, mid: 0, treble: 0 })

  get controlStyle () { return this.ui.settings.knobControlStyle ?? 'directional' }

  /// Same arrangement as the ten-band equaliser: the shipped presets are
  /// read-only on the native side, and "manual" is the one it keeps for edits.
  private static readonly MANUAL_ID = 'manual'
  private currentId = ''
  private peakLimiter = false
  private sendTimer?: number
  private lastSent = 0

  async ngOnInit () {
    this.basic.onSelectedPresetChanged(this.adopt)
    this.adopt(await this.basic.getSelectedPreset())
  }

  private readonly adopt = (preset: BasicEqualizerPreset) => {
    if (!preset) return
    // Once the knobs are on manual its events carry only what this section
    // sent, a round trip late.
    if (preset.id === BasicEqualizerComponent.MANUAL_ID && this.currentId === BasicEqualizerComponent.MANUAL_ID) return
    this.currentId = preset.id
    this.peakLimiter = preset.peakLimiter ?? false
    this.gains.set({ ...preset.gains })
  }

  change (band: BasicEqualizerBand, value: number) {
    this.currentId = BasicEqualizerComponent.MANUAL_ID
    this.gains.update(gains => ({ ...gains, [band]: value }))
    this.schedule()
  }

  @HostListener('window:mouseup')
  released () {
    if (this.sendTimer) this.send()
  }

  private schedule () {
    const now = Date.now()
    if (now - this.lastSent >= SEND_INTERVAL) {
      this.send()
      return
    }
    if (this.sendTimer) return
    this.sendTimer = window.setTimeout(() => this.send(), SEND_INTERVAL - (now - this.lastSent))
  }

  private send () {
    if (this.sendTimer) {
      clearTimeout(this.sendTimer)
      this.sendTimer = undefined
    }
    this.lastSent = Date.now()
    void this.basic.updatePreset(
      {
        id: BasicEqualizerComponent.MANUAL_ID,
        name: 'Manual',
        isDefault: true,
        peakLimiter: this.peakLimiter,
        gains: this.gains()
      },
      // No transition: the native side would ease towards each value while the
      // hand is still turning, and the knob would fight it.
      { select: true, transition: false }
    )
  }

  ngOnDestroy () {
    this.basic.offSelectedPresetChanged(this.adopt)
    if (this.sendTimer) clearTimeout(this.sendTimer)
  }
}
