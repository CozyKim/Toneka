import { Component, Input, Output, EventEmitter, HostBinding, HostListener, ViewChild, ElementRef, ContentChild, ChangeDetectionStrategy, ChangeDetectorRef, inject } from '@angular/core'
import { NgTemplateOutlet } from '@angular/common'
import { ColorsService } from '../services/colors.service'
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
  // Declared first because the colour inputs below read it while they
  // initialise, and fields initialise in the order they are written.
  private readonly colors = inject(ColorsService)

  @Input() labelSide!: 'left' | 'right'
  @Input() labelColor = this.colors.textPrimary
  @Input() interactive: boolean = true
  @Input() checked: boolean = false
  @Output() checkedChange = new EventEmitter<boolean>()
  @Input() color = this.colors.accent
  @Input() bgColor = this.colors.surfaceSunken
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
