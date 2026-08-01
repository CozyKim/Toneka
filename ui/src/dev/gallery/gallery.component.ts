import { Component } from '@angular/core'

import { ContainerComponent } from '../../lib/container/container.component'
import { DividerComponent } from '../../lib/divider/divider.component'
import { LabelComponent } from '../../lib/label/label.component'

@Component({
  // index.html holds a single <app-root>, and the gallery boots into the same
  // page, so it has to answer to that element rather than one of its own.
  selector: 'app-root',
  standalone: true,
  imports: [ ContainerComponent, DividerComponent, LabelComponent ],
  template: `
    <div class="gallery">
      <h1>eqMac widgets</h1>

      <section>
        <h2>label</h2>
        <eqm-label>Plain label</eqm-label>
      </section>

      <section>
        <h2>divider</h2>
        <eqm-divider></eqm-divider>
      </section>

      <section>
        <h2>container</h2>
        <eqm-container>Anything inside</eqm-container>
      </section>
    </div>
  `,
  styles: [`
    /* A checkerboard so anything translucent reads as translucent, the way it
       will over the window's material. */
    .gallery {
      min-height: 100vh;
      padding: var(--space-4);
      color: var(--text-primary);
      font: var(--font-body);
      background-image:
        linear-gradient(45deg, #808080 25%, transparent 25%),
        linear-gradient(-45deg, #808080 25%, transparent 25%),
        linear-gradient(45deg, transparent 75%, #808080 75%),
        linear-gradient(-45deg, transparent 75%, #808080 75%);
      background-size: 24px 24px;
      background-position: 0 0, 0 12px, 12px -12px, -12px 0;
      overflow-y: auto;
    }

    section {
      margin-bottom: var(--space-4);
      padding: var(--space-3);
      border-radius: 8px;
      background: var(--surface);
    }

    h1 { font-size: 18px; margin: 0 0 var(--space-4); }
    h2 { font-size: 12px; margin: 0 0 var(--space-2); color: var(--text-secondary); font-weight: 400; }
  `]
})
export class GalleryComponent {}
