import {
  Component,
  OnInit,
  Input,
  ChangeDetectionStrategy
} from '@angular/core'
import { ContainerComponent } from '../container/container.component'
import { LabelComponent } from '../label/label.component'

@Component({
  selector: 'eqm-value-screen',
  standalone: true,
  imports: [ ContainerComponent, LabelComponent ],
  templateUrl: './value-screen.component.html',
  styleUrls: [ './value-screen.component.scss' ]
})
export class ValueScreenComponent implements OnInit {
  @Input() fontSize = 10
  @Input() enabled = true

  ngOnInit () {}
}
