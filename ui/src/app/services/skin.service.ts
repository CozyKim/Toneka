import { Injectable, inject, signal } from '@angular/core'

import { UIService } from './ui.service'

export const Skins = [ 'rack', 'system' ] as const
export type Skin = typeof Skins[number]

/// The window's own identity rather than the system's. A rack unit is a solid
/// box with its own colours; the system skin hands everything back to macOS.
export const SkinNames: Record<Skin, string> = {
  rack: '랙 유닛',
  system: '시스템'
}

@Injectable({ providedIn: 'root' })
export class SkinService {
  private readonly ui = inject(UIService)

  readonly skin = signal<Skin>('rack')

  constructor () {
    // The attribute is on the document rather than a component, because the
    // tokens are declared on :root and everything below inherits them.
    this.apply(this.skin())
  }

  async sync () {
    const settings = await this.ui.getSettings()
    const stored = settings.skin
    if (stored && (Skins as readonly string[]).includes(stored)) {
      this.skin.set(stored)
      this.apply(stored)
    }
  }

  async set (skin: Skin) {
    this.skin.set(skin)
    this.apply(skin)
    await this.ui.setSettings({ skin })
  }

  private apply (skin: Skin) {
    document.documentElement.dataset['skin'] = skin
  }
}
