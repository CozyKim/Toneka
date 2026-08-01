import { Component, OnInit, Input, Output, EventEmitter, ViewChild, ElementRef, ChangeDetectionStrategy } from '@angular/core'
import { ScrollingModule } from '@angular/cdk/scrolling'
import { ContainerComponent } from '../container/container.component'
import { IconComponent } from '../icon/icon.component'
import { LabelComponent } from '../label/label.component'

@Component({
  selector: 'eqm-select-box',
  standalone: true,
  imports: [ ScrollingModule, ContainerComponent, IconComponent, LabelComponent ],
  templateUrl: './select-box.component.html',
  styleUrls: [ './select-box.component.scss' ],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class SelectBoxComponent implements OnInit {
  _items: any[] = []
  @Input()
  set items (newItems: any[]) {
    this._items = newItems
    this.setHeight()
  }

  get items () {
    return this._items
  }

  @Input() labelParam = 'text'
  // Annotated rather than left to inference: the items are whatever the caller
  // hands over, and inferring null from the default makes every read of a
  // property on it a type error.
  @Input() selectedItem: any = null
  @Output() itemSelected = new EventEmitter()
  @ViewChild('container', { read: ElementRef, static: true }) container!: ElementRef
  public _nVisibleItems: number = 6
  @Input()
  set numberOfVisibleItems (value: number) {
    if (!isNaN(value)) {
      this._nVisibleItems = value
      this.setHeight()
    }
  }

  get numberOfVisibleItems () {
    return this._nVisibleItems
  }

  height = 0
  @Input() width?: number
  hidden = true
  itemHeight = 25

  constructor (public host: ElementRef) {
  }

  ngOnInit () {
    this.setDimensions()
  }

  public setDimensions () {
    this.setHeight()
    this.setWidth()
  }

  public setHeight () {
    const lowest = Math.min(this._nVisibleItems, this.items.length)
    this.height = lowest * this.itemHeight + (this.numberOfVisibleItems < this.items.length ? this.itemHeight / 2 : 0)
    this.host.nativeElement.style.height = `${this.height}px`
  }

  public setWidth () {
    if (this.width) {
      this.host.nativeElement.style.height = `${this.height}px`
    }
  }

  selectItem (item: any) {
    this.selectedItem = item
    this.itemSelected.emit(item)
  }
}
