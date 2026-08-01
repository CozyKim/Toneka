import { Component, OnInit, inject, signal } from '@angular/core'

import { ApplicationService } from './services/app.service'

@Component({
  selector: 'app-root',
  standalone: true,
  template: `
    <main class="shell">
      <p class="shell__placeholder">{{ status() }}</p>
    </main>
  `,
  styles: [`
    .shell {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100vw;
      height: 100vh;
    }

    .shell__placeholder {
      color: var(--text-primary);
      font: var(--font-body);
      margin: 0;
    }
  `]
})
export class AppComponent implements OnInit {
  private readonly app = inject(ApplicationService)
  readonly status = signal('connecting')

  async ngOnInit () {
    try {
      const info = await this.app.getInfo()
      this.status.set(`eqMac ${info.version}`)
    } catch (err) {
      this.status.set('bridge unavailable')
      console.error(err)
    }
  }
}
