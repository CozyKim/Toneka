import { Component } from '@angular/core'

@Component({
  selector: 'app-root',
  standalone: true,
  template: `
    <main class="shell">
      <p class="shell__placeholder">eqMac</p>
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
export class AppComponent {}
