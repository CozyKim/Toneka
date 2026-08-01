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

  'GET /effects/equalizers/advanced/presets': () => ({ data: state.equalizers.advanced.presets }),
  'GET /effects/equalizers/advanced/presets/selected': () => ({
    data: state.equalizers.advanced.presets.find(p => p.id === state.equalizers.advanced.selected)
  }),
  'POST /effects/equalizers/advanced/presets/select': data => {
    state.equalizers.advanced.selected = String(data?.['id'])
    return {}
  },
  'POST /effects/equalizers/advanced/presets': data => {
    const preset = data as any
    const at = state.equalizers.advanced.presets.findIndex(p => p.id === preset.id)
    if (at >= 0) state.equalizers.advanced.presets[at] = preset
    else state.equalizers.advanced.presets.push(preset)
    if (preset.select) state.equalizers.advanced.selected = preset.id
    return {}
  },
  'GET /effects/equalizers/advanced/settings/show-default-presets': () => read('show', true),
  'POST /effects/equalizers/advanced/settings/show-default-presets': () => ({}),

  'GET /effects/equalizers/basic/presets': () => ({ data: state.equalizers.basic.presets }),
  'GET /effects/equalizers/basic/presets/selected': () => ({
    data: state.equalizers.basic.presets.find(p => p.id === state.equalizers.basic.selected)
  }),
  'POST /effects/equalizers/basic/presets/select': data => {
    state.equalizers.basic.selected = String(data?.['id'])
    return {}
  },
  'POST /effects/equalizers/basic/presets': data => {
    const preset = data as any
    const at = state.equalizers.basic.presets.findIndex(p => p.id === preset.id)
    if (at >= 0) state.equalizers.basic.presets[at] = preset
    else state.equalizers.basic.presets.push(preset)
    if (preset.select) state.equalizers.basic.selected = preset.id
    return {}
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
