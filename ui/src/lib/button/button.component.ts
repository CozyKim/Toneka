import { Component, OnInit, Input, Output, EventEmitter, ChangeDetectionStrategy } from '@angular/core'
import { NgStyle } from '@angular/common'

@Component({
  selector: 'eqm-button',
  standalone: true,
  imports: [ NgStyle ],
  templateUrl: './button.component.html',
  styleUrls: [ './button.component.scss' ],
  changeDetection: ChangeDetectionStrategy.Default
})
export class ButtonComponent implements OnInit {
  @Input() type: 'large' | 'narrow' | 'square' | 'circle' | 'transparent' = 'large'
  @Input() height = null
  @Input() width = null
  @Input() state = false
  @Input() toggle = false
  @Input() depressable = true
  @Input() hoverable = true
  @Input() backgroundColor = 'var(--control-raised)'
  // Named rather than resolved: a value read here is read once, and the skin
  // can change while the button is on screen.
  @Input() color = 'var(--text-primary)'
  @Output() pressed = new EventEmitter<MouseEvent>()
  @Input() enabled = true

  ngOnInit () {
  }

  get style () {
    return {
      width: `${this.width}px`,
      height: `${this.height}px`,
      backgroundColor: this.type === 'transparent' ? 'transparent' : this.backgroundColor,
      color: this.color
    }
  }

  computeClass () {
    let className = 'button'
    className += ` ${this.type}`
    className += this.state ? ' on' : ' off'
    if (this.enabled) {
      className += ' enabled'
    }
    if (this.hoverable) {
      className += ' hoverable-' + (this.state ? 'on' : 'off')
    }
    return className
  }

  click (event: MouseEvent) {
    event.stopPropagation()
    if (this.enabled) {
      if (this.toggle) {
        if (this.state && this.depressable) {
          this.state = !this.state
        }
      } else {
        this.state = true
        setTimeout(() => {
          this.state = false
        }, 100)
      }
      this.pressed.emit(event)
    }
  }
}
