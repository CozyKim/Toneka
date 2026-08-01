import {
  Component,
  OnInit,
  Input,
  ViewEncapsulation,
  ChangeDetectionStrategy,
  inject
} from '@angular/core'
import { NgStyle } from '@angular/common'
import { svgs, IconName } from './icons'
import { DomSanitizer, SafeHtml } from '@angular/platform-browser'
import { ColorsService } from '../services/colors.service'

@Component({
  selector: 'eqm-icon',
  standalone: true,
  imports: [ NgStyle ],
  templateUrl: './icon.component.html',
  styleUrls: [ './icon.component.scss' ],
  encapsulation: ViewEncapsulation.None,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class IconComponent implements OnInit {
  // Declared first because the colour fields below read it while they
  // initialise, and fields initialise in the order they are written.
  private readonly colors = inject(ColorsService)

  @Input() width = 20
  @Input() height = 20
  svg?: SafeHtml
  icons = svgs

  @Input() set size (newSize: number) {
    this.width = newSize
    this.height = newSize
  }

  // The unset colour is a value, not a var(), because it ends up in an inline
  // fill on the container that the SVG inherits from.
  private readonly defaultColor = this.colors.textSecondary

  _color = this.defaultColor
  @Input()
  set color (newColor: string) {
    if (newColor && newColor !== '') {
      this._color = newColor
    } else {
      this._color = this.defaultColor
    }
  }

  _strokeColor = this._color
  @Input()
  set strokeColor (newColor: string) {
    if (newColor && newColor !== '') {
      this._strokeColor = newColor
    } else {
      this._strokeColor = this._color
    }
  }

  public _rotate = 0
  @Input()
  get rotate () {
    return this._rotate
  }

  set rotate (angle: number) {
    this._rotate = angle
  }

  _name!: IconName
  @Input()
  set name (iconName: IconName) {
    this._name = iconName
    this.svg = this.sanitizer.bypassSecurityTrustHtml(this.icons[this.name])
  }

  get name () { return this._name }

  @Input() stroke: number = 0

  constructor (public sanitizer: DomSanitizer) {}
  ngOnInit () {
  }

  get style () {
    const style: any = {}

    style.fill = `${this._color}`
    style.display = 'block'
    style.margin = '0 auto'
    if (this.height >= 0) {
      style.height = `${this.height}px`
    }
    if (this.height >= 0) {
      style.width = `${this.width}px`
    }
    style.transform = `rotate(${this.rotate}deg)`
    style['-webkit-transform'] = `rotate(${this.rotate}deg)`

    if (this.stroke) {
      style['stroke-width'] = `${this.stroke}px`
      style.stroke = `${this._strokeColor}`
    }

    return style
  }
}

export * from './icons'
