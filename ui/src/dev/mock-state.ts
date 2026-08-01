//
//  Mock replies for the browser harness.
//
//  Pure: no browser APIs, no imports from the app. That keeps it runnable with
//  `node mock-state.ts` so the route table can be checked without a build.
//

export interface MockReply {
  data?: unknown
  error?: string
}

export type MockRequest = Record<string, any> | undefined

/// Mutable so a POST is visible to the GET that follows it, the way the native
/// side behaves.
const state = {
  enabled: true,
  info: {
    name: 'eqMac',
    model: 'MacBookPro18,3',
    version: '1.3.2',
    isOpenSource: true
  },
  ui: {
    width: 400,
    height: 500,
    minWidth: 400,
    minHeight: 400,
    maxWidth: null as number | null,
    maxHeight: null as number | null,
    scale: 1,
    mode: 'window',
    alwaysOnTop: false,
    resizable: true,
    statusItemIconType: 'classic',
    settings: {
      replaceKnobsWithSliders: false,
      knobControlStyle: 'directional',
      volumeFeatureEnabled: true,
      balanceFeatureEnabled: true,
      equalizersFeatureEnabled: true,
      outputFeatureEnabled: true,
      showEqualizers: true
    } as Record<string, any>
  }
}

/// A GET that reads one field, paired with the key the caller destructures.
function read (key: string, value: unknown): MockReply {
  return { data: { [key]: value } }
}

/// A POST that stores one field of `state.ui` and echoes nothing, which is what
/// the native routes do.
function write<K extends keyof typeof state.ui> (key: K, value: (typeof state.ui)[K]): MockReply {
  state.ui[key] = value
  return {}
}

const routes: Record<string, (data: MockRequest) => MockReply> = {
  'GET /info': () => ({ data: state.info }),
  'GET /enabled': () => read('enabled', state.enabled),
  'POST /enabled': data => { state.enabled = Boolean(data?.['enabled']); return {} },
  'GET /quit': () => ({}),
  'GET /faq': () => { console.info('[harness] faq'); return {} },
  'POST /bug': () => { console.info('[harness] bug'); return {} },
  'GET /haptic': () => ({}),
  'GET /update': () => ({ data: 'Updates are not available in this build.' }),
  'GET /alert-sound': () => ({}),
  'POST /system-sound': () => ({}),
  'POST /open-url': data => { console.info('[harness] open-url', data?.['url']); return {} },
  'GET /bundle-icon': () => read('base64', ''),

  'GET /ui/width': () => read('width', state.ui.width),
  'POST /ui/width': data => write('width', Number(data?.['width'])),
  'GET /ui/height': () => read('height', state.ui.height),
  'POST /ui/height': data => write('height', Number(data?.['height'])),
  'GET /ui/min-width': () => read('minWidth', state.ui.minWidth),
  'POST /ui/min-width': data => write('minWidth', Number(data?.['minWidth'])),
  'GET /ui/min-height': () => read('minHeight', state.ui.minHeight),
  'POST /ui/min-height': data => write('minHeight', Number(data?.['minHeight'])),
  'GET /ui/max-width': () => read('maxWidth', state.ui.maxWidth),
  'POST /ui/max-width': data => write('maxWidth', data?.['maxWidth'] ?? null),
  'GET /ui/max-height': () => read('maxHeight', state.ui.maxHeight),
  'POST /ui/max-height': data => write('maxHeight', data?.['maxHeight'] ?? null),
  'GET /ui/scale': () => read('scale', state.ui.scale),
  'POST /ui/scale': data => write('scale', Number(data?.['scale'])),
  'GET /ui/mode': () => read('mode', state.ui.mode),
  'POST /ui/mode': data => write('mode', String(data?.['mode'])),
  'GET /ui/always-on-top': () => read('alwaysOnTop', state.ui.alwaysOnTop),
  'POST /ui/always-on-top': data => write('alwaysOnTop', Boolean(data?.['alwaysOnTop'])),
  'GET /ui/resizable': () => read('resizable', state.ui.resizable),
  'POST /ui/resizable': data => write('resizable', Boolean(data?.['resizable'])),
  'GET /ui/status-item-icon-type': () => read('statusItemIconType', state.ui.statusItemIconType),
  'POST /ui/status-item-icon-type': data => write('statusItemIconType', String(data?.['statusItemIconType'])),

  // Settings are returned whole, not wrapped: getSettings() and setSettings()
  // both use the reply as the settings object itself.
  'GET /ui/settings': () => ({ data: state.ui.settings }),
  'POST /ui/settings': data => {
    state.ui.settings = { ...state.ui.settings, ...(data ?? {}) }
    return { data: state.ui.settings }
  },

  'GET /ui/close': () => { console.info('[harness] close'); return {} },
  'GET /ui/hide': () => { console.info('[harness] hide'); return {} },
  'POST /ui/loaded': () => ({})
}

/// Every route the interface can reach. Unknown handlers come back as an error
/// rather than silently resolving, so a typo shows up instead of hanging.
export function respond (handler: string, data?: MockRequest): MockReply {
  const route = routes[handler]
  if (!route) {
    return { error: `[harness] no mock for "${handler}"` }
  }
  return route(data)
}

export const mockRoutes = Object.keys(routes)
