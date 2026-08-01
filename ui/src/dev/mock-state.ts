//
//  Mock replies for the browser harness.
//
//  Pure: no browser APIs, no imports from the app. That keeps it runnable with
//  `node mock-state.ts` so the route table can be checked without a build.
//

export interface MockReply {
  data?: unknown
  error?: string
  /// What the native side would push after handling this request. Returned
  /// rather than emitted so this file stays free of browser APIs; the bridge
  /// stub fires them.
  events?: Array<{ event: string, data: unknown }>
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
      skin: 'rack',
      volumeFeatureEnabled: true,
      balanceFeatureEnabled: true,
      equalizersFeatureEnabled: true,
      outputFeatureEnabled: true,
      showEqualizers: true
    } as Record<string, any>
  },
  outputs: {
    devices: [
      { id: 51, name: 'MacBook Pro 스피커', transportType: 'builtIn' },
      { id: 73, name: 'AirPods Pro', transportType: 'bluetooth' },
      { id: 94, name: 'Studio Display', transportType: 'displayPort' }
    ],
    selected: 51
  },
  volume: { gain: 0.62, muted: false, balance: 0, boost: false },
  settings: { launchOnStartup: false, iconMode: 'statusBar' },
  equalizers: {
    enabled: true,
    // 'Basic' and 'Advanced' with a capital: the native enum's raw values.
    type: 'Advanced',
    advanced: {
      presets: [
        // The native side synthesises "manual" and edits land on it, so it is
        // the one the bands write to rather than the preset in front of them.
        { id: 'manual', name: 'Manual', isDefault: true, gains: { global: 0, bands: Array(10).fill(0) } },
        { id: 'flat', name: 'Flat', isDefault: true, gains: { global: 0, bands: Array(10).fill(0) } },
        { id: 'bassBooster', name: 'Bass Booster', isDefault: true, gains: { global: 0, bands: [ 11, 8.5, 7, 5, 2.5, 0, 0, 0, 0, 0 ] } }
      ] as any[],
      selected: 'flat'
    },
    basic: {
      presets: [
        { id: 'manual', name: 'Manual', isDefault: true, peakLimiter: false, gains: { bass: 0, mid: 0, treble: 0 } },
        { id: 'flat', name: 'Flat', isDefault: true, peakLimiter: false, gains: { bass: 0, mid: 0, treble: 0 } }
      ] as any[],
      selected: 'flat'
    }
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

/// The two equalisers keep their presets the same way and answer the same four
/// routes, so they are described once. Each one pushes the new list and the new
/// selection after it changes them, which is what the native side does and what
/// the sections listen for -- they never re-read after a write.
function presetRoutes (route: string, store: { presets: any[], selected: string }) {
  const list = () => ({ event: `${route}/presets`, data: store.presets })
  const chosen = () => ({
    event: `${route}/presets/selected`,
    data: store.presets.find(preset => preset.id === store.selected)
  })

  return {
    [`GET ${route}/presets`]: () => ({ data: store.presets }),
    [`GET ${route}/presets/selected`]: () => ({
      data: store.presets.find(preset => preset.id === store.selected)
    }),
    [`POST ${route}/presets/select`]: (data: MockRequest) => {
      store.selected = String(data?.['id'])
      return { events: [ chosen() ] }
    },
    // An id means update and no id means create, the way the native route
    // reads it.
    [`POST ${route}/presets`]: (data: MockRequest) => {
      const preset = { ...(data as any) }
      preset.id ??= `user-${store.presets.length}`
      preset.isDefault ??= false
      const at = store.presets.findIndex(p => p.id === preset.id)
      if (at >= 0) store.presets[at] = preset
      else store.presets.push(preset)
      if (preset.select) store.selected = preset.id
      return { data: preset, events: preset.select ? [ list(), chosen() ] : [ list() ] }
    },
    [`DELETE ${route}/presets`]: (data: MockRequest) => {
      store.presets = store.presets.filter(preset => preset.id !== String(data?.['id']))
      store.selected = 'flat'
      return { events: [ list(), chosen() ] }
    }
  }
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

  'GET /outputs/devices': () => ({ data: state.outputs.devices }),
  'GET /outputs/selected': () => read('id', state.outputs.selected),
  'POST /outputs/selected': data => {
    state.outputs.selected = Number(data?.['id'])
    return {}
  },

  'GET /volume/gain': () => read('gain', state.volume.gain),
  'POST /volume/gain': data => { state.volume.gain = Number(data?.['gain']); return {} },
  'GET /volume/muted': () => read('muted', state.volume.muted),
  'POST /volume/muted': data => { state.volume.muted = Boolean(data?.['muted']); return {} },
  'GET /volume/balance': () => read('balance', state.volume.balance),
  'POST /volume/balance': data => { state.volume.balance = Number(data?.['balance']); return {} },
  'GET /volume/gain/boost/enabled': () => read('enabled', state.volume.boost),
  'POST /volume/gain/boost/enabled': data => { state.volume.boost = Boolean(data?.['enabled']); return {} },

  'GET /effects/equalizers/enabled': () => read('enabled', state.equalizers.enabled),
  'POST /effects/equalizers/enabled': data => { state.equalizers.enabled = Boolean(data?.['enabled']); return {} },
  'GET /effects/equalizers/type': () => read('type', state.equalizers.type),
  'POST /effects/equalizers/type': data => { state.equalizers.type = String(data?.['type']); return {} },

  ...presetRoutes('/effects/equalizers/advanced', state.equalizers.advanced),
  ...presetRoutes('/effects/equalizers/basic', state.equalizers.basic),

  // Native file dialogs, which a browser has no counterpart for.
  'GET /effects/equalizers/advanced/presets/import': () => { console.info('[harness] preset import dialog'); return {} },
  'GET /effects/equalizers/advanced/presets/export': () => { console.info('[harness] preset export dialog'); return {} },
  'GET /effects/equalizers/advanced/presets/import-legacy': () => { console.info('[harness] legacy preset import'); return {} },
  'GET /effects/equalizers/advanced/presets/import-legacy/available': () => read('available', false),
  'GET /effects/equalizers/advanced/settings/show-default-presets': () => read('show', true),
  'POST /effects/equalizers/advanced/settings/show-default-presets': () => ({}),

  'GET /settings/launch-on-startup': () => read('state', state.settings.launchOnStartup),
  'POST /settings/launch-on-startup': data => { state.settings.launchOnStartup = Boolean(data?.['state']); return {} },
  'GET /settings/icon-mode': () => read('mode', state.settings.iconMode),
  'POST /settings/icon-mode': data => { state.settings.iconMode = String(data?.['mode']); return {} },

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
