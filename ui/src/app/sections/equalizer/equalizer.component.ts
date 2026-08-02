import { ChangeDetectionStrategy, Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core'

import { ButtonComponent } from '../../../lib/button/button.component'
import { AdvancedEqualizerService, EqualizerPreset } from '../../services/advanced-equalizer.service'
import { BasicEqualizerService } from '../../services/basic-equalizer.service'
import { EqualizersService } from '../../services/equalizers.service'
import { AdvancedEqualizerComponent } from './advanced/advanced.component'
import { BasicEqualizerComponent } from './basic/basic.component'
import { PresetStore, PresetsComponent } from './presets/presets.component'

export type EqualizerMode = 'off' | 'basic' | 'advanced'

@Component({
  selector: 'eqm-equalizer',
  standalone: true,
  imports: [ AdvancedEqualizerComponent, BasicEqualizerComponent, ButtonComponent, PresetsComponent ],
  template: `
    <div class="head">
      <span class="label">EQ</span>
      @for (mode of modes; track mode.key) {
        <eqm-button
          type="narrow"
          [toggle]="true"
          [depressable]="false"
          [state]="current() === mode.key"
          (pressed)="select(mode.key)">
          {{ mode.name }}
        </eqm-button>
      }
      @if (attenuation(); as attenuation) {
        <span class="headroom">{{ attenuation }}</span>
      }
    </div>

    @if (store(); as store) {
      <div class="presets">
        <eqm-presets [store]="store"></eqm-presets>
      </div>
    }

    @switch (current()) {
      @case ('basic')    { <eqm-basic-equalizer class="body"></eqm-basic-equalizer> }
      @case ('advanced') { <eqm-advanced-equalizer class="body"></eqm-advanced-equalizer> }
    }
  `,
  styles: [`
    :host {
      flex: 1;
      min-height: 0;
      display: flex;
      flex-direction: column;
      padding: var(--space-2) var(--space-3);
      gap: var(--space-2);
    }

    .head { display: flex; align-items: center; gap: var(--space-2); }
    .label { font-size: 11px; color: var(--text-secondary); }

    /* Not coloured like the clip lamp, and not shaped like one. The equaliser
       turning itself down is what it does with a boost, not a fault, and the
       only reason to put it on screen is that it would otherwise happen where
       nobody could see it. Last in the row, so appearing moves nothing. */
    .headroom {
      font: var(--font-numeric);
      color: var(--text-secondary);
      font-variant-numeric: tabular-nums;
    }

    /* Its own row rather than beside the segments: at 400px the three of them
       plus a name leave the name nothing to be read in. */
    .presets { display: flex; align-items: center; }

    /* The bands take whatever is left, which is what a taller window buys.
       The recess they sit in is the skin's: a milled well in one and nothing
       at all in the other, where the equaliser sits on the window's material
       like everything around it. */
    .body {
      flex: 1;
      min-height: 0;
      /* Or the padding lands outside the height flex worked out and the last
         row of the window is pushed off the bottom. */
      box-sizing: border-box;
      padding: var(--space-2) var(--space-1);
      border-radius: 3px;
      background: var(--well);
      box-shadow: var(--well-inset);
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class EqualizerComponent implements OnInit, OnDestroy {
  private readonly equalizers = inject(EqualizersService)
  private readonly advanced = inject(AdvancedEqualizerService)
  private readonly basic = inject(BasicEqualizerService)

  /// How much the advanced equaliser is taking back off the output. Zero or
  /// below, and nothing is shown at zero.
  private readonly headroom = signal(0)

  /// Only the advanced equaliser takes anything off, so only it has anything to
  /// say here. Empty when there is nothing to report, which is what the
  /// template reads as "show nothing".
  readonly attenuation = computed(() => {
    if (this.current() !== 'advanced') return ''
    const headroom = this.headroom()
    if (headroom >= 0) return ''
    return `${Math.round(headroom * 10) / 10} dB`.replace('-', '−')
  })

  readonly modes = [
    { key: 'off' as const, name: '끔' },
    { key: 'basic' as const, name: '기본' },
    { key: 'advanced' as const, name: '고급' }
  ]

  readonly current = signal<EqualizerMode>('advanced')

  /// Which list the presets row is showing. Off has no presets to show.
  readonly store = computed<PresetStore<EqualizerPreset> | undefined>(() => {
    switch (this.current()) {
      case 'basic': return this.basic
      case 'advanced': return this.advanced
      case 'off': return undefined
    }
  })

  async ngOnInit () {
    this.advanced.onHeadroomChanged(this.adoptHeadroom)
    const [ enabled, type, headroom ] = await Promise.all([
      this.equalizers.getEnabled(),
      this.equalizers.getType(),
      this.advanced.getHeadroom()
    ])
    this.current.set(enabled ? (type === 'Basic' ? 'basic' : 'advanced') : 'off')
    this.headroom.set(headroom)
  }

  ngOnDestroy () {
    this.advanced.offHeadroomChanged(this.adoptHeadroom)
  }

  /// Bound rather than a method so it can be handed to on/off as the same
  /// reference.
  private readonly adoptHeadroom = ({ headroom }: { headroom: number }) => {
    this.headroom.set(headroom)
  }

  async select (mode: EqualizerMode) {
    this.current.set(mode)
    if (mode === 'off') {
      await this.equalizers.setEnabled(false)
      return
    }
    // Order matters: enabling first would run the previous type for an
    // instant, which is audible.
    await this.equalizers.setType(mode === 'basic' ? 'Basic' : 'Advanced')
    await this.equalizers.setEnabled(true)
  }
}
