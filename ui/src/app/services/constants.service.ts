import { Injectable } from '@angular/core'

@Injectable({
  providedIn: 'root'
})
export class ConstantsService {
  readonly FAQ_URL = new URL('https://github.com/CozyKim/Toneka#faq')
  readonly FEATURES_URL = new URL('https://github.com/CozyKim/Toneka#features')
  readonly BUG_REPORT_URL = new URL('https://github.com/CozyKim/Toneka/issues/new')
}
