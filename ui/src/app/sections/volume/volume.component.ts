import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core'

import { ButtonComponent } from '../../../lib/button/button.component'
import { FlatSliderComponent } from '../../../lib/flat-slider/flat-slider.component'
import { IconComponent } from '../../../lib/icon/icon.component'
import { ToggleComponent } from '../../../lib/toggle/toggle.component'
import { VolumeService } from '../../services/volume.service'

@Component({
  selector: 'eqm-volume',
  standalone: true,
  imports: [ ButtonComponent, FlatSliderComponent, IconComponent, ToggleComponent ],
  template: `
    <div class="row">
      <span class="label">볼륨</span>
      <eqm-flat-slider
        class="field"
        [value]="gain()"
        [min]="0" [max]="ceiling()"
        [stickToMiddle]="false"
        [showMiddleNotch]="false"
        [enabled]="!muted()"
        (userChangedValue)="setGain($event.value)">
      </eqm-flat-slider>
      <span class="readout">{{ percent() }}</span>

      <eqm-button
        type="circle"
        [toggle]="true"
        [depressable]="false"
        [state]="muted()"
        (pressed)="toggleMuted()"
        aria-label="음소거">
        <eqm-icon name="volume" [size]="14"></eqm-icon>
      </eqm-button>

      <span class="label boost">증폭</span>
      <eqm-toggle [state]="boost()" (stateChange)="setBoost($event)"></eqm-toggle>
    </div>

    <div class="row">
      <span class="label">밸런스</span>
      <eqm-flat-slider
        class="field"
        [value]="balance()"
        [min]="-1" [max]="1"
        [stickToMiddle]="true"
        (userChangedValue)="setBalance($event.value)">
      </eqm-flat-slider>
      <span class="readout">{{ side() }}</span>
    </div>
  `,
  styles: [`
    :host {
      flex: 0 0 auto;
      display: flex;
      flex-direction: column;
      justify-content: center;
      gap: var(--space-1);
      padding: var(--space-2) var(--space-3);
      border-bottom: 1px solid var(--surface-raised);
    }

    .row {
      display: flex;
      align-items: center;
      gap: var(--space-2);
      min-height: 26px;
    }

    .label {
      flex: 0 0 38px;
      font-size: 11px;
      color: var(--text-secondary);
    }

    .boost { flex: 0 0 auto; }

    .field { flex: 1; }

    /* Fixed width and tabular figures so the slider beside it does not shift
       as the number grows a digit. */
    .readout {
      flex: 0 0 26px;
      text-align: right;
      font-size: 11px;
      font-variant-numeric: tabular-nums;
      color: var(--text-secondary);
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class VolumeComponent implements OnInit {
  private readonly volume = inject(VolumeService)

  readonly gain = signal(0)
  readonly muted = signal(false)
  readonly balance = signal(0)
  readonly boost = signal(false)

  /// Boost lets the native side amplify past unity, and the slider has to be
  /// able to reach there or the extra range is unusable.
  readonly ceiling = computed(() => this.boost() ? 2 : 1)
  readonly percent = computed(() => Math.round(this.gain() * 100))
  readonly side = computed(() => {
    const balance = this.balance()
    if (balance < -0.01) return 'L'
    if (balance > 0.01) return 'R'
    return 'C'
  })

  async ngOnInit () {
    // Gain moves without the interface asking: the volume keys change it, and
    // so does turning boost off while the gain is above unity.
    this.volume.onGainChanged(({ gain }) => this.gain.set(gain))
    this.volume.onBoostEnabledChanged(({ enabled }) => this.boost.set(enabled))

    const [ gain, muted, balance, boost ] = await Promise.all([
      this.volume.getGain(),
      this.volume.getMuted(),
      this.volume.getBalance(),
      this.volume.getBoostEnabled()
    ])
    this.gain.set(gain)
    this.muted.set(muted)
    this.balance.set(balance)
    this.boost.set(boost)
  }

  setGain (gain: number) {
    this.gain.set(gain)
    void this.volume.setGain(gain)
  }

  toggleMuted () {
    const muted = !this.muted()
    this.muted.set(muted)
    void this.volume.setMuted(muted)
  }

  setBalance (balance: number) {
    this.balance.set(balance)
    void this.volume.setBalance(balance)
  }

  setBoost (enabled: boolean) {
    this.boost.set(enabled)
    void this.volume.setBoostEnabled(enabled)
  }
}
