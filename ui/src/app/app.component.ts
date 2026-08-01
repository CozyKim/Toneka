import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core'

import { ChromeComponent } from './sections/chrome/chrome.component'
import { TitlebarComponent } from './sections/titlebar/titlebar.component'
import { FooterComponent } from './sections/footer/footer.component'
import { OutputComponent } from './sections/output/output.component'
import { VolumeComponent } from './sections/volume/volume.component'
import { EqualizerComponent } from './sections/equalizer/equalizer.component'
import { SettingsComponent } from './sections/settings/settings.component'
import { SkinService } from './services/skin.service'
import { UIService } from './services/ui.service'

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [ ChromeComponent, TitlebarComponent, FooterComponent, OutputComponent, VolumeComponent, EqualizerComponent, SettingsComponent ],
  template: `
    <eqm-titlebar (settingsRequested)="settingsShown.set(true)"></eqm-titlebar>
    <main>
      <eqm-output></eqm-output>
      <eqm-volume></eqm-volume>
      <eqm-equalizer></eqm-equalizer>
    </main>
    <eqm-footer></eqm-footer>
    <eqm-chrome></eqm-chrome>

    @if (settingsShown()) {
      <eqm-settings (closed)="settingsShown.set(false)"></eqm-settings>
    }
  `,
  styles: [`
    :host {
      position: relative;
      display: flex;
      flex-direction: column;
      width: 100vw;
      height: 100vh;
      overflow: hidden;
      color: var(--text-primary);
      font: var(--font-body);
      /* The face of the box in a skin that has one. Where a skin has none this
         is transparent and the window's own material shows through, which is
         what the native side went to the trouble of putting there. */
      background: var(--chrome);
    }

    /* Everything a taller window gains lands here, and nowhere else: the bars
       above and below are fixed, and the equaliser inside this box stretches. */
    main {
      flex: 1;
      min-height: 0;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class AppComponent implements OnInit {
  private readonly ui = inject(UIService)
  private readonly skins = inject(SkinService)

  readonly settingsShown = signal(false)

  async ngOnInit () {
    // Before anything else it could be seen through: the window is painted the
    // moment it is sized, and a frame drawn in the wrong skin and corrected
    // afterwards is a flash the user notices.
    await this.skins.sync()

    // Height is the only dimension the user gets. Ten bands read as ten bands
    // only if their spacing is the same in every window, so width is pinned.
    await Promise.all([
      this.ui.setMinWidth({ minWidth: 400 }),
      this.ui.setMaxWidth({ maxWidth: 400 }),
      this.ui.setMinHeight({ minHeight: 400 }),
      this.ui.setMaxHeight({}),
      this.ui.setResizable(true)
    ])
    await this.ui.loaded()
  }
}
