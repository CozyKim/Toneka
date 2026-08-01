import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core'

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

    /* Its own row rather than beside the segments: at 400px the three of them
       plus a name leave the name nothing to be read in. */
    .presets { display: flex; align-items: center; }

    /* The bands take whatever is left, which is what a taller window buys. */
    .body { flex: 1; min-height: 0; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class EqualizerComponent implements OnInit {
  private readonly equalizers = inject(EqualizersService)
  private readonly advanced = inject(AdvancedEqualizerService)
  private readonly basic = inject(BasicEqualizerService)

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
    const [ enabled, type ] = await Promise.all([
      this.equalizers.getEnabled(),
      this.equalizers.getType()
    ])
    this.current.set(enabled ? (type === 'Basic' ? 'basic' : 'advanced') : 'off')
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
