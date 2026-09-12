import { ApplicationConfig, ErrorHandler } from '@angular/core'
import { provideAnimations } from '@angular/platform-browser/animations'

import { NativeLogErrorHandler } from './services/native-log-error-handler'

export const appConfig: ApplicationConfig = {
  providers: [
    provideAnimations(),
    { provide: ErrorHandler, useClass: NativeLogErrorHandler }
  ]
}
