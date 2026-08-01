import { ChangeDetectionStrategy, Component, OnInit, inject } from '@angular/core'
import { ColorsService } from '../services/colors.service'
import { IconComponent } from '../icon/icon.component'

@Component({
  selector: 'eqm-question',
  standalone: true,
  imports: [ IconComponent ],
  template: '<eqm-icon [stroke]="0" [color]="colors.textPrimary" [width]="8" [height]="8" name="help"></eqm-icon>',
  styles: [ ':host { height: 12px; width: 12px; display: flex; align-items: center; justify-content: center; border-radius: 50%; background-color: var(--control); }' ],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class QuestionComponent implements OnInit {
  readonly colors = inject(ColorsService)

  ngOnInit () {
  }
}
