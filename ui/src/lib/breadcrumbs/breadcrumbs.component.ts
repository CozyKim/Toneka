import { ChangeDetectionStrategy, ChangeDetectorRef, Component, EventEmitter, Input, OnInit, Output } from '@angular/core'
import { IconComponent } from '../icon/icon.component'
import { LabelComponent } from '../label/label.component'

@Component({
  selector: 'eqm-breadcrumbs',
  standalone: true,
  imports: [ IconComponent, LabelComponent ],
  templateUrl: './breadcrumbs.component.html',
  styleUrls: [ './breadcrumbs.component.scss' ],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class BreadcrumbsComponent implements OnInit {
  @Input() crumbs!: string[]
  @Input() underline = true
  @Output() crumbClicked = new EventEmitter<{ crumb: string, index: number }>()

  ngOnInit (): void {
  }
}
