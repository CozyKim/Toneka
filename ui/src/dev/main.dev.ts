import { bootstrapApplication } from '@angular/platform-browser'

import { AppComponent } from '../app/app.component'
import { appConfig } from '../app/app.config'
import { installBridgeStub } from './bridge-stub'

// Services call sync() from their constructors, so the bridge has to be in
// place before anything is injected.
installBridgeStub()

bootstrapApplication(AppComponent, appConfig)
  .catch(err => console.error(err))
