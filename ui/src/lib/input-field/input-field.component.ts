import { Component, OnInit, Input, EventEmitter, Output, ViewChild, HostBinding, ElementRef, ChangeDetectionStrategy } from '@angular/core'
import { FormsModule } from '@angular/forms'
import { ContainerComponent } from '../container/container.component'

@Component({
  selector: 'eqm-input-field',
  standalone: true,
  imports: [ FormsModule, ContainerComponent ],
  templateUrl: './input-field.component.html',
  styleUrls: [ './input-field.component.scss' ],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class InputFieldComponent implements OnInit {
  @Input() text?: string
  @Input() placeholder = ''
  @Output() textChange = new EventEmitter()
  @Output() enter = new EventEmitter()
  @Input() editable = true
  @HostBinding('class.enabled') @Input() enabled = true
  @Input() fontSize = 12
  @Input() type: string = 'text'
  // Named rather than resolved: a value read here is read once, and the skin
  // can change while the field is on screen.
  @Input() color = 'var(--accent)'
  @Input() bgColor = 'var(--control-sunken)'
  @ViewChild('container', { static: true }) container!: ElementRef
  ngOnInit () {
  }

  inputChanged () {
    this.textChange.emit(this.text)
  }

  enterPressed () {
    this.enter.emit()
  }
}
