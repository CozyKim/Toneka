import { Injectable } from '@angular/core'

/// Reads the colour tokens declared in styles/tokens.scss.
///
/// The widgets that draw into a canvas or an SVG need the value rather than a
/// class, and having them keep their own copy is how the interface ended up
/// with fifty-three hardcoded colours. Reading the token means light and dark
/// follow the system without anything here knowing which is in effect.
@Injectable({ providedIn: 'root' })
export class ColorsService {
  // The tokens are declared on :root, so the element read through has to be in
  // the document to inherit them. It is never painted.
  private readonly probe = document.createElement('span')

  constructor () {
    this.probe.style.display = 'none'
    this.probe.setAttribute('aria-hidden', 'true')
    document.body.appendChild(this.probe)
  }

  /// `name` is the custom property without the leading dashes, e.g. "accent".
  value (name: string): string {
    const declared = getComputedStyle(document.documentElement)
      .getPropertyValue(`--${name}`)
      .trim()

    if (!declared) {
      console.warn(`[colors] no token named --${name}`)
      return declared
    }

    // Resolved through a real colour property rather than handed back as
    // declared. A token may hold AccentColor or a color-mix(), and a canvas
    // refuses both as text; reading it back off `color` yields plain rgb().
    this.probe.style.color = ''
    this.probe.style.color = `var(--${name})`
    return getComputedStyle(this.probe).color
  }

  get accent () { return this.value('accent') }
  get accentBright () { return this.value('accent-bright') }
  get warning () { return this.value('warning') }
  get caution () { return this.value('caution') }
  get textPrimary () { return this.value('text-primary') }
  get textSecondary () { return this.value('text-secondary') }
  get surface () { return this.value('surface') }
  get surfaceRaised () { return this.value('surface-raised') }
  get surfaceSunken () { return this.value('surface-sunken') }
  get iconGradientStart () { return this.value('icon-gradient-start') }
  get iconGradientMiddle () { return this.value('icon-gradient-middle') }
  get iconGradientEnd () { return this.value('icon-gradient-end') }
}
