import { ChangeDetectionStrategy, Component } from '@angular/core'

import { AdvancedEqualizerComponent } from './advanced/advanced.component'

@Component({
  selector: 'eqm-equalizer',
  standalone: true,
  imports: [ AdvancedEqualizerComponent ],
  template: `
    <div class="head">
      <span class="label">EQ</span>
    </div>
    <eqm-advanced-equalizer class="body"></eqm-advanced-equalizer>
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
export class EqualizerComponent {}
