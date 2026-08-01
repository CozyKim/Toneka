import { Component } from '@angular/core'

import { BreadcrumbsComponent } from '../../lib/breadcrumbs/breadcrumbs.component'
import { ButtonComponent } from '../../lib/button/button.component'
import { CheckboxComponent } from '../../lib/checkbox/checkbox.component'
import { ContainerComponent } from '../../lib/container/container.component'
import { DividerComponent } from '../../lib/divider/divider.component'
import { DropdownComponent } from '../../lib/dropdown/dropdown.component'
import { FlatSliderComponent } from '../../lib/flat-slider/flat-slider.component'
import { IconComponent } from '../../lib/icon/icon.component'
import { KnobComponent } from '../../lib/knob/knob.component'
import { InputFieldComponent } from '../../lib/input-field/input-field.component'
import { LabelComponent } from '../../lib/label/label.component'
import { LoadingComponent } from '../../lib/loading/loading.component'
import { ScrewComponent } from '../../lib/screw/screw.component'
import { SelectBoxComponent } from '../../lib/select-box/select-box.component'
import { SkeuomorphSliderComponent } from '../../lib/skeuomorph-slider/skeuomorph-slider.component'
import { ToggleComponent } from '../../lib/toggle/toggle.component'
import { ValueScreenComponent } from '../../lib/value-screen/value-screen.component'
import { VentComponent } from '../../lib/vent/vent.component'

@Component({
  // index.html holds a single <app-root>, and the gallery boots into the same
  // page, so it has to answer to that element rather than one of its own.
  selector: 'app-root',
  standalone: true,
  imports: [
    BreadcrumbsComponent,
    ButtonComponent,
    CheckboxComponent,
    ContainerComponent,
    DividerComponent,
    DropdownComponent,
    FlatSliderComponent,
    IconComponent,
    InputFieldComponent,
    KnobComponent,
    LabelComponent,
    LoadingComponent,
    ScrewComponent,
    SelectBoxComponent,
    SkeuomorphSliderComponent,
    ToggleComponent,
    ValueScreenComponent,
    VentComponent
  ],
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

      <section>
        <h2>value-screen</h2>
        <div class="row">
          <eqm-value-screen>0.0</eqm-value-screen>
          <eqm-value-screen [fontSize]="16">-3.5</eqm-value-screen>
          <eqm-value-screen [enabled]="false">off</eqm-value-screen>
        </div>
      </section>

      <section>
        <h2>screw</h2>
        <eqm-screw></eqm-screw>
      </section>

      <section>
        <h2>vent</h2>
        <eqm-vent></eqm-vent>
      </section>

      <section>
        <h2>breadcrumbs</h2>
        <eqm-breadcrumbs [crumbs]="crumbs" (crumbClicked)="lastCrumb = $event.crumb"></eqm-breadcrumbs>
        <span>{{ lastCrumb }}</span>
      </section>

      <section>
        <h2>loading</h2>
        <eqm-loading></eqm-loading>
      </section>

      <section>
        <h2>icon</h2>
        <div class="row">
          @for (name of iconNames; track name) {
            <eqm-icon [name]="name" [width]="16" [height]="16"></eqm-icon>
          }
        </div>
      </section>

      <section>
        <h2>button</h2>
        <div class="row">
          <eqm-button (pressed)="presses = presses + 1">Press</eqm-button>
          <eqm-button type="narrow" [toggle]="true" [state]="true">Narrow</eqm-button>
          <eqm-button type="circle"><eqm-icon name="cog" [size]="16"></eqm-icon></eqm-button>
          <eqm-button [enabled]="false">Disabled</eqm-button>
          <span>{{ presses }} presses</span>
        </div>
      </section>

      <section>
        <h2>toggle / checkbox</h2>
        <div class="row">
          <eqm-toggle [(state)]="toggled"></eqm-toggle>
          <span>{{ toggled }}</span>
          <eqm-checkbox [(checked)]="checked"></eqm-checkbox>
          <span>{{ checked }}</span>
          <eqm-checkbox [(checked)]="checked" labelSide="right">With a label</eqm-checkbox>
        </div>
      </section>

      <section>
        <h2>input-field</h2>
        <div class="narrow-column">
          <eqm-input-field [(text)]="typed" placeholder="Type here"></eqm-input-field>
        </div>
        <span>{{ typed }}</span>
      </section>

      <section>
        <h2>select-box</h2>
        <div class="narrow-column">
          <eqm-select-box [items]="items" [selectedItem]="selected" (itemSelected)="selected = $event"></eqm-select-box>
        </div>
        <span>{{ selected.text }}</span>
      </section>

      <section>
        <h2>dropdown</h2>
        <div class="narrow-column">
          <eqm-dropdown [items]="items" [(selectedItem)]="selected"></eqm-dropdown>
        </div>
        <span>{{ selected.text }}</span>
      </section>

      <section>
        <h2>knob</h2>
        <div class="row">
          <eqm-knob [(value)]="knobValue" [min]="-24" [max]="24"></eqm-knob>
          <span>{{ knobValue }}</span>
          <eqm-knob size="large" [(value)]="knobValue" [min]="-24" [max]="24"></eqm-knob>
          <eqm-knob size="small" [(value)]="knobValue" [min]="-24" [max]="24"></eqm-knob>
        </div>
      </section>

      <section>
        <h2>flat-slider</h2>
        <div class="narrow-column">
          <eqm-flat-slider [(value)]="flatValue"></eqm-flat-slider>
        </div>
        <span>{{ flatValue }}</span>
      </section>

      <section>
        <h2>skeuomorph-slider</h2>
        <div class="row tall">
          <eqm-skeuomorph-slider [(value)]="skeuoValue"></eqm-skeuomorph-slider>
          <span>{{ skeuoValue }}</span>
        </div>
      </section>
    </div>
  `,
  styles: [`
    /* A checkerboard so anything translucent reads as translucent, the way it
       will over the window's material. */
    .gallery {
      /* Bounded rather than min-height: the body clips at the viewport, so a
         gallery that grows past it would put its last widgets out of reach. */
      height: 100vh;
      box-sizing: border-box;
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

    .row { display: flex; gap: var(--space-2); align-items: center; }

    /* Widgets that lay themselves out at the full width of their parent need
       one, or they stretch across the whole gallery. */
    .narrow-column { width: 180px; }

    /* The select box sets its own height but leaves its display alone, and an
       inline box ignores height. In the app a dropdown wraps it in a fixed
       position, which blocks it; standing on its own here it needs saying. */
    .narrow-column eqm-select-box { display: block; }

    /* The skeuomorph slider fills the height it is given, so it needs one. */
    .row.tall { height: 160px; align-items: stretch; }

    h1 { font-size: 18px; margin: 0 0 var(--space-4); }
    h2 { font-size: 12px; margin: 0 0 var(--space-2); color: var(--text-secondary); font-weight: 400; }
  `]
})
export class GalleryComponent {
  readonly iconNames = [ 'cross', 'bluetooth', 'hdmi', 'airplay', 'cog' ] as const
  readonly crumbs = [ 'Outputs', 'Built-in', 'Advanced' ]
  lastCrumb = ''

  // The list widgets read their label off a property of each item rather than
  // taking plain strings, so the items here are objects.
  readonly items = [
    { text: 'One', icon: 'speaker' },
    { text: 'Two', icon: 'headphones' },
    { text: 'Three', icon: 'bluetooth' },
    { text: 'Four' },
    { text: 'Five' },
    { text: 'Six' },
    { text: 'Seven' },
    { text: 'Eight' }
  ]

  selected: { text: string, icon?: string } = this.items[0]
  toggled = false
  checked = false
  typed = ''
  presses = 0
  knobValue = 0
  flatValue = 0.5
  skeuoValue = 0
}
