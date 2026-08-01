import { ChangeDetectionStrategy, Component, OnDestroy, OnInit, inject, signal } from '@angular/core'

import { SpectrumService } from '../../../services/spectrum.service'
import { UIService } from '../../../services/ui.service'

const BANDS = 10

/// What is actually coming out, one bar per equaliser band and standing behind
/// them. It shows and does not control: the sliders in front of it are what the
/// hand reaches for, and this takes no pointer events at all.
@Component({
  selector: 'eqm-spectrum',
  standalone: true,
  template: `
    @for (level of levels(); track $index) {
      <div class="band">
        <div class="bar" [style.height.%]="level * 100"></div>
      </div>
    }
  `,
  styles: [`
    /* The same column layout the bands and the curve use, so a bar stands under
       the handle it belongs to without either of them being told the other's
       measurements. */
    :host {
      display: flex;
      align-items: stretch;
    }

    .band {
      flex: 1;
      min-width: 0;
      display: flex;
      justify-content: center;
      align-items: flex-end;
    }

    /* Narrower than its column: at full width the ten of them meet and read as
       one filled shape rather than as ten readings.

       A faint body under a brighter top edge, which is the part the eye follows.
       The edge is thin enough to be bright without adding weight, and an inset
       shadow rather than a border so that a band at rest leaves no line behind.
       Both stay under the curve in front: the curve is what was asked for and
       the bars are what came of it. */
    .bar {
      width: 52%;
      background: var(--spectrum-bar);
      box-shadow: inset 0 2px 0 var(--spectrum-peak);
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class SpectrumComponent implements OnInit, OnDestroy {
  private readonly spectrum = inject(SpectrumService)
  private readonly ui = inject(UIService)

  /// A signal rather than an input: these arrive thirty times a second, and
  /// through an input the change would be detected up the whole tree above.
  readonly levels = signal<number[]>(Array(BANDS).fill(0))

  ngOnInit () {
    this.spectrum.onVolumes(this.receive)
    this.ui.onShownChanged(this.windowShown)
    void this.spectrum.setEnabled(true)
  }

  ngOnDestroy () {
    this.spectrum.offVolumes(this.receive)
    this.ui.offShownChanged(this.windowShown)
    void this.spectrum.setEnabled(false)
  }

  /// Bound rather than methods so they can be handed to on and off as the same
  /// reference.
  private readonly receive = (volumes: number[]) => {
    this.levels.set(volumes)
  }

  /// A hidden window is still a live component, and a transform running behind
  /// one nobody can see is battery spent on nothing.
  private readonly windowShown = ({ isShown }: { isShown: boolean }) => {
    void this.spectrum.setEnabled(isShown)
    if (!isShown) this.levels.set(Array(BANDS).fill(0))
  }
}
