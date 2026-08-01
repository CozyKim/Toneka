import { ChangeDetectionStrategy, Component, inject } from '@angular/core'

import { ScrewComponent } from '../../../lib/screw/screw.component'
import { VentComponent } from '../../../lib/vent/vent.component'
import { SkinService } from '../../services/skin.service'

/// The only place in the interface that asks which skin is on. Everything else
/// reads tokens, which is why the values differ without the tree doing so;
/// hardware a system skin has no counterpart for has to be absent rather than
/// merely colourless, and absence is not something a token can express.
///
/// Nothing here carries a value or takes an event.
@Component({
  selector: 'eqm-chrome',
  standalone: true,
  imports: [ ScrewComponent, VentComponent ],
  template: `
    @if (skins.skin() === 'rack') {
      <eqm-vent class="vent"></eqm-vent>
      <eqm-screw class="tr"></eqm-screw>
      <eqm-screw class="br"></eqm-screw>
    }
  `,
  styles: [`
    /* Over the whole window and deaf to the pointer, so a screw that lands on
       a control does not stop it being used. */
    :host {
      position: absolute;
      inset: 0;
      z-index: 5;
      pointer-events: none;
    }

    /* Down the right edge only. The top left is where the window draws its
       close and minimise buttons, and a screw would sit under them. */
    .tr, .br { position: absolute; right: 8px; }
    .tr { top: 12px; }
    .br { bottom: 11px; }

    /* Fills the empty run of the title strip between the name and the settings
       glyph, clear of both. Given as two edges rather than a width because the
       slits are a repeating gradient and simply keep going: the strip can be
       any length and they stay the same size. */
    .vent {
      position: absolute;
      top: 12px;
      left: 176px;
      right: 60px;
      height: 12px;
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ChromeComponent {
  readonly skins = inject(SkinService)
}
