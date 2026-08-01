import { ChangeDetectionStrategy, Component, EventEmitter, OnInit, Output, inject, signal } from '@angular/core'

import { CheckboxComponent } from '../../../lib/checkbox/checkbox.component'
import { ContainerComponent } from '../../../lib/container/container.component'
import { ClickedOutsideDirective } from '../../../lib/directives/clicked-outside.directive'
import { DropdownComponent } from '../../../lib/dropdown/dropdown.component'
import { KnobControlStyle } from '../../../lib/knob/knob.component'
import { IconMode, SettingsService } from '../../services/settings.service'
import { UIService } from '../../services/ui.service'

interface Choice<T> { id: T, name: string }

const ICON_MODES: Array<Choice<IconMode>> = [
  { id: IconMode.statusBar, name: '상태 막대' },
  { id: IconMode.dock, name: 'Dock' },
  { id: IconMode.both, name: '둘 다' },
  { id: IconMode.neither, name: '없음' }
]

const KNOB_STYLES: Array<Choice<KnobControlStyle>> = [
  { id: 'directional', name: '위아래로 끌기' },
  { id: 'rotational', name: '돌리기' }
]

@Component({
  selector: 'eqm-settings',
  standalone: true,
  imports: [ CheckboxComponent, ContainerComponent, ClickedOutsideDirective, DropdownComponent ],
  template: `
    <eqm-container class="sheet" (clickedOutside)="closed.emit()">
      <h2>설정</h2>

      <label class="row">
        <span class="name">로그인 시 실행</span>
        <eqm-checkbox
          labelSide="right"
          [checked]="launchOnStartup()"
          (checkedChange)="setLaunchOnStartup($event)">
        </eqm-checkbox>
      </label>

      <label class="row">
        <span class="name">항상 위에</span>
        <eqm-checkbox
          labelSide="right"
          [checked]="alwaysOnTop()"
          (checkedChange)="setAlwaysOnTop($event)">
        </eqm-checkbox>
      </label>

      <div class="row">
        <span class="name">메뉴 막대 아이콘</span>
        <eqm-dropdown
          class="field"
          labelParam="name"
          [items]="iconModes"
          [selectedItem]="iconMode()"
          (selectedItemChange)="setIconMode($event)">
        </eqm-dropdown>
      </div>

      <div class="row">
        <span class="name">노브 조작</span>
        <eqm-dropdown
          class="field"
          labelParam="name"
          [items]="knobStyles"
          [selectedItem]="knobStyle()"
          (selectedItemChange)="setKnobStyle($event)">
        </eqm-dropdown>
      </div>
    </eqm-container>
  `,
  styles: [`
    /* Covers the window rather than pushing it about: two settings are not
       worth a place of their own in a 400px interface. */
    :host {
      position: absolute;
      inset: 0;
      z-index: 10;
      display: grid;
      place-items: center;
      padding: var(--space-3);
      background: var(--surface-sunken);
    }

    .sheet {
      width: 100%;
      display: flex;
      flex-direction: column;
      gap: var(--space-3);
      padding: var(--space-3);
      border-radius: 8px;
    }

    h2 {
      margin: 0;
      font-size: 12px;
      font-weight: 600;
      color: var(--text-secondary);
    }

    .row {
      display: flex;
      align-items: center;
      gap: var(--space-2);
    }

    .name { flex: 1; font-size: 12px; }
    .field { flex: 0 0 140px; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class SettingsComponent implements OnInit {
  private readonly settings = inject(SettingsService)
  private readonly ui = inject(UIService)

  @Output() closed = new EventEmitter<void>()

  readonly iconModes = ICON_MODES
  readonly knobStyles = KNOB_STYLES

  readonly launchOnStartup = signal(false)
  readonly alwaysOnTop = signal(false)
  readonly iconMode = signal<Choice<IconMode> | undefined>(undefined)
  readonly knobStyle = signal<Choice<KnobControlStyle> | undefined>(undefined)

  async ngOnInit () {
    const [ launchOnStartup, iconMode, alwaysOnTop ] = await Promise.all([
      this.settings.getLaunchOnStartup(),
      this.settings.getIconMode(),
      this.ui.getAlwaysOnTop()
    ])
    this.launchOnStartup.set(launchOnStartup)
    this.alwaysOnTop.set(alwaysOnTop)
    this.iconMode.set(ICON_MODES.find(mode => mode.id === iconMode))
    this.knobStyle.set(KNOB_STYLES.find(style => style.id === this.ui.settings.knobControlStyle))
  }

  setLaunchOnStartup (state: boolean) {
    this.launchOnStartup.set(state)
    void this.settings.setLaunchOnStartup(state)
  }

  setAlwaysOnTop (alwaysOnTop: boolean) {
    this.alwaysOnTop.set(alwaysOnTop)
    void this.ui.setAlwaysOnTop({ alwaysOnTop })
  }

  setIconMode (mode: Choice<IconMode>) {
    this.iconMode.set(mode)
    void this.settings.setIconMode(mode.id)
  }

  setKnobStyle (style: Choice<KnobControlStyle>) {
    this.knobStyle.set(style)
    void this.ui.setSettings({ knobControlStyle: style.id })
  }
}
