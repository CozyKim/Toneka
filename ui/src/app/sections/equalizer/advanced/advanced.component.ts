import {
  ChangeDetectionStrategy,
  Component,
  HostListener,
  OnDestroy,
  OnInit,
  inject,
  signal
} from '@angular/core'

import { FlatSliderComponent } from '../../../../lib/flat-slider/flat-slider.component'
import { AdvancedEqualizerPreset, AdvancedEqualizerService } from '../../../services/advanced-equalizer.service'

/// Fixed on the native side; the interface only labels them.
const FREQUENCIES = [ 32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000 ] as const

/// The range the native presets are written in: the shipped "Acoustic" reaches
/// past eighteen decibels, so a narrower slider would misreport it.
const LIMIT = 24

/// Dragging emits on every mouse move. Sending each one would put a request on
/// the bridge every few milliseconds; this is the rate the widgets already
/// animate at, so it is fast enough to hear as continuous.
const SEND_INTERVAL = 1000 / 30

@Component({
  selector: 'eqm-advanced-equalizer',
  standalone: true,
  imports: [ FlatSliderComponent ],
  template: `
    <div class="bands">
      <div class="grid" aria-hidden="true"></div>
      @for (frequency of frequencies; track frequency; let i = $index) {
        <div class="band">
          <eqm-flat-slider
            orientation="vertical"
            [min]="-limit" [max]="limit"
            [value]="gains()[i]"
            [stickToMiddle]="true"
            (userChangedValue)="setBand(i, $event.value)">
          </eqm-flat-slider>
          <span class="frequency">{{ label(frequency) }}</span>
        </div>
      }
    </div>
  `,
  styles: [`
    :host {
      display: flex;
      flex-direction: column;
      min-height: 0;
    }

    .bands {
      position: relative;
      flex: 1;
      min-height: 0;
      display: flex;
      align-items: stretch;
    }

    .band {
      flex: 1;
      min-width: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: var(--space-1);
    }

    eqm-flat-slider {
      flex: 1;
      min-height: 0;
    }

    .frequency {
      flex: 0 0 auto;
      font-size: 9px;
      color: var(--text-secondary);
      font-variant-numeric: tabular-nums;
    }

    /* The decibel scale belongs to the row of bands rather than to any one of
       them, so it is drawn once behind all ten. The lines sit at -24, -12, 0,
       +12 and +24, and the middle one is brighter because it is unity. */
    .grid {
      position: absolute;
      inset: 0 0 14px;
      pointer-events: none;
      background:
        linear-gradient(var(--surface-raised), var(--surface-raised)) 0 0 / 100% 1px no-repeat,
        linear-gradient(var(--surface-raised), var(--surface-raised)) 0 25% / 100% 1px no-repeat,
        linear-gradient(var(--text-secondary), var(--text-secondary)) 0 50% / 100% 1px no-repeat,
        linear-gradient(var(--surface-raised), var(--surface-raised)) 0 75% / 100% 1px no-repeat,
        linear-gradient(var(--surface-raised), var(--surface-raised)) 0 100% / 100% 1px no-repeat;
      opacity: 0.6;
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class AdvancedEqualizerComponent implements OnInit, OnDestroy {
  private readonly advanced = inject(AdvancedEqualizerService)

  readonly frequencies = FREQUENCIES
  readonly limit = LIMIT
  readonly gains = signal<number[]>(Array(FREQUENCIES.length).fill(0))

  /// The gains ride on a preset, and the shipped ones are read-only on the
  /// native side. "manual" is the one it keeps for edits, so a band that moves
  /// copies what is on screen into it and selects it.
  private static readonly MANUAL_ID = 'manual'
  private global = 0
  private currentId = ''
  private sendTimer?: number
  private lastSent = 0

  async ngOnInit () {
    this.advanced.onSelectedPresetChanged(this.adopt)
    this.adopt(await this.advanced.getSelectedPreset())
  }

  label (frequency: number) {
    return frequency >= 1000 ? `${frequency / 1000}k` : `${frequency}`
  }

  /// Bound rather than a method so it can be handed to on/off as the same
  /// reference.
  private readonly adopt = (preset: AdvancedEqualizerPreset) => {
    if (!preset) return
    // Every write comes back as an event. Once the bands are already on the
    // manual preset that echo carries nothing this component did not send, and
    // it arrives a round trip late -- adopting it would undo whichever band
    // moved while the last one was still travelling.
    if (preset.id === AdvancedEqualizerComponent.MANUAL_ID && this.currentId === AdvancedEqualizerComponent.MANUAL_ID) return
    this.currentId = preset.id
    this.global = preset.gains.global
    this.gains.set([ ...preset.gains.bands ])
  }

  setBand (index: number, value: number) {
    // Moving a band is an edit to the manual preset from this moment on, so
    // the echoes it produces stop being adopted from here.
    this.currentId = AdvancedEqualizerComponent.MANUAL_ID
    this.gains.update(gains => {
      const next = [ ...gains ]
      next[index] = value
      return next
    })
    this.schedule()
  }

  @HostListener('window:mouseup')
  released () {
    // The throttle may have swallowed the last move, and that one is the value
    // the user let go on.
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
    void this.advanced.updatePreset(
      {
        id: AdvancedEqualizerComponent.MANUAL_ID,
        name: 'Manual',
        isDefault: true,
        gains: { bands: this.gains(), global: this.global }
      },
      // No transition: the native side would ease towards each value while the
      // hand is still moving, and the slider would fight it.
      { select: true, transition: false }
    )
  }

  ngOnDestroy () {
    this.advanced.offSelectedPresetChanged(this.adopt)
    if (this.sendTimer) clearTimeout(this.sendTimer)
  }
}
