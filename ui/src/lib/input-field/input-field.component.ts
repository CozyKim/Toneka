import { Component, OnInit, Input, EventEmitter, Output, ViewChild, HostBinding, ElementRef, ChangeDetectionStrategy, inject } from '@angular/core'
import { FormsModule } from '@angular/forms'
import { ColorsService } from '../services/colors.service'
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
  // Declared first because the colour inputs below read it while they
  // initialise, and fields initialise in the order they are written.
  private readonly colors = inject(ColorsService)

  @Input() text?: string
  @Input() placeholder = ''
  @Output() textChange = new EventEmitter()
  @Output() enter = new EventEmitter()
  @Input() editable = true
  @HostBinding('class.enabled') @Input() enabled = true
  @Input() fontSize = 12
  @Input() type: string = 'text'
  @Input() color = this.colors.accent
  @Input() bgColor = this.colors.surfaceSunken
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
