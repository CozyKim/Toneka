import { ChangeDetectionStrategy, Component, Input } from '@angular/core'
import { TooltipService } from './tooltip.service'
import { FadeInOutAnimation } from '../animations/fade-in-out'
import { TooltipComponent } from './tooltip.component'

@Component({
  selector: 'eqm-tooltip-container',
  standalone: true,
  imports: [ TooltipComponent ],
  template: `
    <div class="tooltip-container">
      @for (tooltip of tooltipService.components; track $index) {
        <eqm-tooltip
          [text]="tooltip.text"
          [parent]="tooltip.parent"
          [positionSide]="tooltip.positionSide"
          [scale]="scale"
          [showArrow]="tooltip.showArrow">
        </eqm-tooltip>
      }
    </div>
  `,
  animations: [ FadeInOutAnimation ],
  styles: [
    `:host {
      z-index: 10000;
    }`
  ]
})
export class TooltipContainerComponent {
  @Input() scale = 1
  constructor (public tooltipService: TooltipService) {}
}
