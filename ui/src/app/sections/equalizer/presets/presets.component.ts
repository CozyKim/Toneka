import { ChangeDetectionStrategy, Component, Input, OnChanges, OnDestroy, signal } from '@angular/core'

import { ButtonComponent } from '../../../../lib/button/button.component'
import { DropdownComponent } from '../../../../lib/dropdown/dropdown.component'
import { IconComponent } from '../../../../lib/icon/icon.component'
import { InputFieldComponent } from '../../../../lib/input-field/input-field.component'
import { EqualizerPreset } from '../../../services/advanced-equalizer.service'

/// The part of an equaliser service this component needs. Both equalisers
/// already satisfy it, so neither is named here and a third would need no new
/// code.
/// Declared with method syntax on purpose. A store hands out presets of its own
/// shape and is only ever given those same ones back, which is exactly the
/// bivariance that method parameters allow and function-typed properties do
/// not.
export interface PresetStore<P extends EqualizerPreset> {
  getPresets (): Promise<P[]>
  getSelectedPreset (): Promise<P>
  selectPreset (preset: P): Promise<unknown>
  createPreset (preset: any, select?: boolean): Promise<unknown>
  deletePreset (preset: P): Promise<unknown>
  onPresetsChanged (cb: (presets: P[]) => void): void
  offPresetsChanged (cb: (presets: P[]) => void): void
  onSelectedPresetChanged (cb: (preset: P) => void): void
  offSelectedPresetChanged (cb: (preset: P) => void): void
  /// Only the advanced equaliser has these. Asking the store rather than
  /// taking a flag keeps the caller from having to know which one it handed
  /// over.
  importPresets? (): Promise<unknown>
  exportPresets? (): Promise<unknown>
}

@Component({
  selector: 'eqm-presets',
  standalone: true,
  imports: [ ButtonComponent, DropdownComponent, IconComponent, InputFieldComponent ],
  template: `
    @if (naming()) {
      <eqm-input-field
        class="list"
        placeholder="새 프리셋 이름"
        [text]="name()"
        (textChange)="name.set($event)"
        (enter)="save()">
      </eqm-input-field>
      <eqm-button type="narrow" (pressed)="save()">저장</eqm-button>
      <eqm-button type="narrow" (pressed)="naming.set(false)">취소</eqm-button>
    } @else {
      <eqm-dropdown
        class="list"
        labelParam="name"
        [items]="presets()"
        [selectedItem]="selected()"
        (selectedItemChange)="select($event)">
      </eqm-dropdown>

      <eqm-button type="square" (pressed)="startNaming()" aria-label="프리셋 저장">
        <eqm-icon name="download" [size]="12"></eqm-icon>
      </eqm-button>

      @if (canRemove()) {
        <eqm-button type="square" (pressed)="remove()" aria-label="프리셋 삭제">
          <eqm-icon name="cross" [size]="12"></eqm-icon>
        </eqm-button>
      }

      @if (canTransfer) {
        <eqm-button type="square" (pressed)="store.importPresets!()" aria-label="가져오기">
          <eqm-icon name="open" [size]="12"></eqm-icon>
        </eqm-button>
        <eqm-button type="square" (pressed)="store.exportPresets!()" aria-label="내보내기">
          <eqm-icon name="send" [size]="12"></eqm-icon>
        </eqm-button>
      }
    }
  `,
  styles: [`
    :host { display: flex; align-items: center; gap: var(--space-1); flex: 1; min-width: 0; }
    .list { flex: 1; min-width: 0; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class PresetsComponent implements OnChanges, OnDestroy {
  @Input({ required: true }) store!: PresetStore<EqualizerPreset>

  readonly presets = signal<EqualizerPreset[]>([])
  readonly selected = signal<EqualizerPreset | undefined>(undefined)
  readonly naming = signal(false)
  readonly name = signal('')

  /// The store this component is currently subscribed to. Held separately from
  /// the input so that the old one can be unsubscribed from when the input is
  /// swapped -- switching the equaliser mode hands over a different list, and
  /// a component that read its input once would keep showing the other one.
  private attached?: PresetStore<EqualizerPreset>

  get canTransfer () { return typeof this.store.importPresets === 'function' }

  /// The native side refuses to delete a shipped preset, so the button that
  /// would only fail is not offered.
  canRemove () {
    const preset = this.selected()
    return preset !== undefined && !preset.isDefault
  }

  async ngOnChanges () {
    if (this.attached === this.store) return
    this.detach()
    const store = this.store
    this.attached = store
    this.naming.set(false)
    this.presets.set([])
    this.selected.set(undefined)

    store.onPresetsChanged(this.adoptPresets)
    store.onSelectedPresetChanged(this.adoptSelected)
    const [ presets, selected ] = await Promise.all([
      store.getPresets(),
      store.getSelectedPreset()
    ])
    // The mode may have been switched again while these were in flight.
    if (this.attached !== store) return
    this.presets.set(presets)
    this.adoptSelected(selected)
  }

  private detach () {
    if (!this.attached) return
    this.attached.offPresetsChanged(this.adoptPresets)
    this.attached.offSelectedPresetChanged(this.adoptSelected)
    this.attached = undefined
  }

  private readonly adoptPresets = (presets: EqualizerPreset[]) => {
    if (!presets) return
    this.presets.set(presets)
    // The list was rebuilt, so the object the dropdown compares against is no
    // longer one of its items.
    const id = this.selected()?.id
    if (id !== undefined) this.selected.set(presets.find(preset => preset.id === id))
  }

  private readonly adoptSelected = (preset: EqualizerPreset) => {
    if (!preset) return
    this.selected.set(this.presets().find(p => p.id === preset.id) ?? preset)
  }

  select (preset: EqualizerPreset) {
    this.selected.set(preset)
    void this.store.selectPreset(preset)
  }

  startNaming () {
    this.name.set('')
    this.naming.set(true)
  }

  async save () {
    const name = this.name().trim()
    if (!name) return
    this.naming.set(false)
    // Saved from what is on the bands right now, which is what the selected
    // preset holds by the time a band has moved.
    const current = await this.store.getSelectedPreset()
    await this.store.createPreset({ name, gains: current.gains }, true)
  }

  remove () {
    const preset = this.selected()
    if (!preset || preset.isDefault) return
    void this.store.deletePreset(preset)
  }

  ngOnDestroy () {
    this.detach()
  }
}
