import { bootstrapApplication } from '@angular/platform-browser'

import { AppComponent } from '../app/app.component'
import { appConfig } from '../app/app.config'
import { GalleryComponent } from './gallery/gallery.component'
import { installBridgeStub } from './bridge-stub'

// Services call sync() from their constructors, so the bridge has to be in
// place before anything is injected.
installBridgeStub()

// ?gallery shows the widgets instead of the interface. Same stub, same server.
const root = location.search.includes('gallery') ? GalleryComponent : AppComponent

bootstrapApplication(root, appConfig)
  .catch(err => console.error(err))
