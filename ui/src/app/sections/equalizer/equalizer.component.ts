import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core'

import { ButtonComponent } from '../../../lib/button/button.component'
import { EqualizersService } from '../../services/equalizers.service'
import { AdvancedEqualizerComponent } from './advanced/advanced.component'
import { BasicEqualizerComponent } from './basic/basic.component'

export type EqualizerMode = 'off' | 'basic' | 'advanced'

@Component({
  selector: 'eqm-equalizer',
  standalone: true,
  imports: [ AdvancedEqualizerComponent, BasicEqualizerComponent, ButtonComponent ],
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

    /* The bands take whatever is left, which is what a taller window buys. */
    .body { flex: 1; min-height: 0; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class EqualizerComponent implements OnInit {
  private readonly equalizers = inject(EqualizersService)

  readonly modes = [
    { key: 'off' as const, name: '끔' },
    { key: 'basic' as const, name: '기본' },
    { key: 'advanced' as const, name: '고급' }
  ]

  readonly current = signal<EqualizerMode>('advanced')

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
