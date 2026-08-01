import {
  Component,
  Input,
  HostBinding,
  ChangeDetectionStrategy
} from '@angular/core'

@Component({
  selector: 'eqm-value-screen',
  standalone: true,
  templateUrl: './value-screen.component.html',
  styleUrls: [ './value-screen.component.scss' ],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ValueScreenComponent {
  // On the host rather than on a box inside it, so the screen is exactly as
  // wide as the number it holds and whatever places it decides the rest.
  @HostBinding('style.font-size.px') @Input() fontSize = 10
  @HostBinding('class.enabled') @Input() enabled = true
}
