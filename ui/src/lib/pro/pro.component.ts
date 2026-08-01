import { ChangeDetectionStrategy, Component, Input, inject } from '@angular/core'
import { NgStyle } from '@angular/common'
import { ColorsService } from '../services/colors.service'
import { LabelComponent } from '../label/label.component'

@Component({
  selector: 'eqm-pro',
  standalone: true,
  imports: [ NgStyle, LabelComponent ],
  template: `
    <div [ngStyle]="style">
      <eqm-label [fontSize]="fontSize" [color]="color">Pro</eqm-label>
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ProComponent {
  // Declared first because the colour inputs below read it while they
  // initialise, and fields initialise in the order they are written.
  public colors = inject(ColorsService)

  @Input() color = this.colors.textPrimary
  @Input() backgroundColor = this.colors.surfaceSunken
  @Input() fontSize = 14

  get style () {
    return {
      display: 'inline-block',
      backgroundColor: this.backgroundColor,
      color: this.color,
      borderRadius: '4px',
      padding: '2px 4px'
    }
  }
}
