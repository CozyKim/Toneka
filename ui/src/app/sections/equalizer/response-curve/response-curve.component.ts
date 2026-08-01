import { ChangeDetectionStrategy, Component, ElementRef, Input, OnDestroy, computed, inject, signal } from '@angular/core'

/// The shape the bands add up to, drawn from their values alone. It shows and
/// does not control: the sliders in front of it are what the hand reaches for,
/// and this takes no pointer events at all.
@Component({
  selector: 'eqm-response-curve',
  standalone: true,
  template: `
    <svg [attr.viewBox]="'0 0 ' + box().w + ' ' + box().h" preserveAspectRatio="none">
      @for (line of gridLines; track line) {
        <line [attr.x1]="0" [attr.x2]="box().w"
              [attr.y1]="line * box().h" [attr.y2]="line * box().h"
              [attr.stroke-dasharray]="line === 0.5 ? null : '2 3'"
              [attr.stroke-width]="line === 0.5 ? 1 : 0.5" />
      }
      <path class="fill" [attr.d]="areaPath()" />
      <path class="line" [attr.d]="linePath()" />
    </svg>
  `,
  styles: [`
    :host { display: block; position: relative; }
    svg { width: 100%; height: 100%; display: block; }
    line { stroke: var(--grid-line); }
    .fill { fill: var(--curve-fill); stroke: none; }
    .line { fill: none; stroke: var(--curve-line); stroke-width: 1.8; stroke-linecap: round; }
  `],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ResponseCurveComponent implements OnDestroy {
  private readonly host = inject(ElementRef<HTMLElement>)

  @Input({ required: true }) set gains (value: number[]) { this._gains.set([ ...value ]) }
  @Input() range = 24

  private readonly _gains = signal<number[]>([])

  readonly gridLines = [ 0, 0.25, 0.5, 0.75, 1 ]

  // Same reason the sliders needed one: the application runs without zone.js,
  // so a layout change raises no change detection and the viewBox would keep
  // the size the element had when it was first drawn.
  private readonly _box = signal({ w: 300, h: 100 })
  readonly box = this._box.asReadonly()

  private readonly observer = new ResizeObserver(entries => {
    const rect = entries[0].contentRect
    if (rect.width > 0 && rect.height > 0) {
      this._box.set({ w: Math.round(rect.width), h: Math.round(rect.height) })
    }
  })

  constructor () {
    this.observer.observe(this.host.nativeElement)
  }

  ngOnDestroy () {
    this.observer.disconnect()
  }

  /// Each gain owns an equal slice of the width and sits in the middle of it,
  /// which is where the band that carries it stands. Anchoring them to the
  /// edges instead would leave the outer two beside their own handles.
  ///
  /// The six pixels off the top and bottom are the room the handle needs: a
  /// slider's travel stops a thumb-radius short of each end, so a curve drawn
  /// to the full height would climb past the handle at full boost.
  private readonly points = computed(() => {
    const gains = this._gains()
    const { w, h } = this._box()
    if (gains.length < 2) return []
    const step = w / gains.length
    return gains.map((gain, i) => [
      step * (i + 0.5),
      h / 2 - (gain / this.range) * (h / 2 - 6)
    ] as [ number, number ])
  })

  /// Catmull-Rom through the points, written as the cubic Béziers an SVG path
  /// can hold: the ten bands are samples of one response and a polyline would
  /// draw them as ten unrelated corners.
  readonly linePath = computed(() => {
    const pts = this.points()
    if (pts.length < 2) return ''
    let d = `M ${pts[0][0]} ${pts[0][1]}`
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = pts[i - 1] ?? pts[i]
      const p1 = pts[i]
      const p2 = pts[i + 1]
      const p3 = pts[i + 2] ?? p2
      d += ` C ${p1[0] + (p2[0] - p0[0]) / 6} ${p1[1] + (p2[1] - p0[1]) / 6},` +
           ` ${p2[0] - (p3[0] - p1[0]) / 6} ${p2[1] - (p3[1] - p1[1]) / 6},` +
           ` ${p2[0]} ${p2[1]}`
    }
    return d
  })

  /// The same line closed along unity, so the fill reads as the distance from
  /// flat rather than as everything under the curve.
  readonly areaPath = computed(() => {
    const pts = this.points()
    const line = this.linePath()
    if (!line || pts.length < 2) return ''
    const mid = this._box().h / 2
    return `${line} L ${pts[pts.length - 1][0]} ${mid} L ${pts[0][0]} ${mid} Z`
  })
}
