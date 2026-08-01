import { ChangeDetectionStrategy, Component, OnInit, inject } from '@angular/core'

import { TitlebarComponent } from './sections/titlebar/titlebar.component'
import { FooterComponent } from './sections/footer/footer.component'
import { OutputComponent } from './sections/output/output.component'
import { UIService } from './services/ui.service'

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [ TitlebarComponent, FooterComponent, OutputComponent ],
  template: `
    <eqm-titlebar></eqm-titlebar>
    <main>
      <eqm-output></eqm-output>
    </main>
    <eqm-footer></eqm-footer>
  `,
  styles: [`
    :host {
      display: flex;
      flex-direction: column;
      width: 100vw;
      height: 100vh;
      overflow: hidden;
      color: var(--text-primary);
      font: var(--font-body);
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

  async ngOnInit () {
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
