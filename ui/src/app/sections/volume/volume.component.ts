import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core'

import { ButtonComponent } from '../../../lib/button/button.component'
import { FlatSliderComponent } from '../../../lib/flat-slider/flat-slider.component'
import { IconComponent } from '../../../lib/icon/icon.component'
import { ToggleComponent } from '../../../lib/toggle/toggle.component'
import { ValueScreenComponent } from '../../../lib/value-screen/value-screen.component'
import { VolumeService } from '../../services/volume.service'

@Component({
  selector: 'eqm-volume',
  standalone: true,
  imports: [ ButtonComponent, FlatSliderComponent, IconComponent, ToggleComponent, ValueScreenComponent ],
  template: `
    <div class="row">
      <span class="label">볼륨</span>
      <eqm-flat-slider
        class="field"
        [value]="gain()"
        [min]="0" [max]="ceiling()"
        [thickness]="6"
        [thumbRadius]="7"
        [stickToMiddle]="false"
        [showMiddleNotch]="false"
        [enabled]="!muted()"
        (userChangedValue)="setGain($event.value)">
      </eqm-flat-slider>
      <eqm-value-screen class="readout" [fontSize]="11" [enabled]="!muted()">{{ percent() }}</eqm-value-screen>

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
        [thickness]="6"
        [thumbRadius]="7"
        [stickToMiddle]="true"
        (userChangedValue)="setBalance($event.value)">
      </eqm-flat-slider>
      <eqm-value-screen class="readout" [fontSize]="11">{{ side() }}</eqm-value-screen>
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
      border-bottom: 1px solid var(--chrome-edge);
      box-shadow: 0 1px 0 var(--chrome-lip);
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

    /* Fixed width so the slider beside it does not shift as the number grows
       a digit. Wide enough for three, which is what boost reaches. */
    .readout { flex: 0 0 34px; }
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
    // These move without the interface asking: the volume keys change gain, as
    // does turning boost off while gain is above unity, and balance belongs to
    // the output device, so changing outputs brings a different one.
    this.volume.onGainChanged(({ gain }) => this.gain.set(gain))
    this.volume.onBalanceChanged(({ balance }) => this.balance.set(balance))
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
