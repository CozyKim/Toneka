import { ChangeDetectionStrategy, Component, inject } from '@angular/core'

import { ApplicationService } from '../../services/app.service'
import { UIService } from '../../services/ui.service'

@Component({
  selector: 'eqm-footer',
  standalone: true,
  template: `
    <button type="button" (click)="app.openFAQ()">도움말</button>
    <button type="button" (click)="app.quit()">종료</button>
    <span class="spacer"></span>
    <span class="version">{{ ui.version }}</span>
  `,
  styles: [`
    :host {
      flex: 0 0 34px;
      display: flex;
      align-items: center;
      gap: var(--space-3);
      padding: 0 var(--space-3);
      border-top: 1px solid var(--surface-raised);
      font-size: 11px;
      color: var(--text-secondary);
    }

    .spacer { flex: 1; }
    .version { font-variant-numeric: tabular-nums; }

    button {
      padding: 0;
      border: 0;
      background: transparent;
      color: inherit;
      font: inherit;
      cursor: default;
    }

    button:hover { color: var(--text-primary); }
    button:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class FooterComponent {
  readonly app = inject(ApplicationService)
  readonly ui = inject(UIService)
}
