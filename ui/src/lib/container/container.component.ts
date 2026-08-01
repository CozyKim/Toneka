import { Component, OnInit, HostBinding, Input, ChangeDetectionStrategy } from '@angular/core'

@Component({
  selector: 'eqm-container',
  standalone: true,
  templateUrl: './container.component.html',
  styleUrls: [ './container.component.scss' ]
})
export class ContainerComponent implements OnInit {
  @HostBinding('class.enabled') @Input() enabled = true
  @Input() @HostBinding('style.background-color') color = 'var(--control-sunken)'
  ngOnInit () {
  }
}
