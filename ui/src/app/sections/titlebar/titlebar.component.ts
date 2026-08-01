import { ChangeDetectionStrategy, Component, EventEmitter, OnInit, Output, inject, signal } from '@angular/core'

import { ApplicationService } from '../../services/app.service'
import { IconComponent } from '../../../lib/icon/icon.component'
import { ToggleComponent } from '../../../lib/toggle/toggle.component'

@Component({
  selector: 'eqm-titlebar',
  standalone: true,
  imports: [ IconComponent, ToggleComponent ],
  template: `
    <eqm-toggle [state]="enabled()" (stateChange)="setEnabled($event)"></eqm-toggle>
    <span class="name">eqMac</span>
    <span class="spacer"></span>
    <button class="glyph" type="button" (click)="settingsRequested.emit()" aria-label="설정">
      <eqm-icon name="cog" [size]="14"></eqm-icon>
    </button>
  `,
  styles: [`
    :host {
      flex: 0 0 36px;
      display: flex;
      align-items: center;
      gap: var(--space-2);
      padding: 0 var(--space-3);
      border-bottom: 1px solid var(--surface-raised);
    }

    .name { font-weight: 600; }
    .spacer { flex: 1; }

    .glyph {
      display: grid;
      place-items: center;
      width: 22px;
      height: 22px;
      padding: 0;
      border: 0;
      border-radius: 6px;
      background: transparent;
      color: var(--text-secondary);
      cursor: default;
    }

    .glyph:hover { background: var(--surface); }
    .glyph:focus-visible { outline: 2px solid var(--accent); outline-offset: 1px; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class TitlebarComponent implements OnInit {
  private readonly app = inject(ApplicationService)

  // The sheet covers the whole window, so it belongs to whoever owns the
  // window rather than to this strip.
  @Output() settingsRequested = new EventEmitter<void>()

  // Held in a signal rather than read off the service: the service fills its
  // own field from an asynchronous reply, and a plain field settling later
  // leaves an OnPush view showing whatever it guessed first.
  readonly enabled = signal(true)

  async ngOnInit () {
    this.enabled.set(await this.app.getEnabled())
  }

  setEnabled (enabled: boolean) {
    this.enabled.set(enabled)
    void this.app.setEnabled(enabled)
  }
}
