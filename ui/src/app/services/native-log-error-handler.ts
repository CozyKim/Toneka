import { ErrorHandler, Injectable, inject } from '@angular/core'

import { ApplicationService } from './app.service'

/// Sends every unhandled error -- thrown or a rejected promise nobody awaited
/// -- to the native side, so it lands in the log file next to the native
/// entries instead of staying in the web view's console, which nothing keeps.
@Injectable()
export class NativeLogErrorHandler implements ErrorHandler {
  private readonly app = inject(ApplicationService)

  handleError (error: unknown) {
    console.error(error)
    // A failed report must not come back through here: the console line
    // above is all it gets.
    this.app.reportError(describe(error)).catch(() => {})
  }
}

function describe (error: unknown): string {
  if (error instanceof Error) {
    return error.stack ?? `${error.name}: ${error.message}`
  }
  if (typeof error === 'string') return error
  try {
    return JSON.stringify(error)
  } catch {
    return String(error)
  }
}
