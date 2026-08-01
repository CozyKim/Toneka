import { Component, Input, Output, EventEmitter, HostBinding, HostListener, ViewChild, ElementRef, ContentChild, ChangeDetectionStrategy, ChangeDetectorRef, inject } from '@angular/core'
import { NgTemplateOutlet } from '@angular/common'
import { ContainerComponent } from '../container/container.component'
import { IconComponent } from '../icon/icon.component'
import { LabelComponent } from '../label/label.component'

@Component({
  selector: 'eqm-checkbox',
  standalone: true,
  imports: [ NgTemplateOutlet, ContainerComponent, IconComponent, LabelComponent ],
  templateUrl: './checkbox.component.html',
  styleUrls: [ './checkbox.component.scss' ],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class CheckboxComponent {
  @Input() labelSide!: 'left' | 'right'
  // Named rather than resolved: a value read here is read once, and the skin
  // can change while the checkbox is on screen.
  @Input() labelColor = 'var(--text-primary)'
  @Input() interactive: boolean = true
  @Input() checked: boolean = false
  @Output() checkedChange = new EventEmitter<boolean>()
  @Input() color = 'var(--accent)'
  @Input() bgColor = 'var(--control-sunken)'
  @HostBinding('class.enabled') @Input() enabled = true

  constructor (
    private readonly change: ChangeDetectorRef
  ) {}

  @HostListener('click')
  toggle () {
    if (this.interactive && this.enabled) {
      this.checked = !this.checked
      this.checkedChange.emit(this.checked)
      this.change.detectChanges()
    }
  }
}
