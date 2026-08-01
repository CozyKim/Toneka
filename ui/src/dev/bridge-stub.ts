//
//  Fills in for the bridge the native side injects, so the interface runs in a
//  plain browser.
//
//  bridge.service.ts uses window.WebViewJavascriptBridge when it is already
//  there, so nothing in the application has to know this exists.
//

import { respond } from './mock-state'

// Derived from the shape the application declares for the injected bridge, so
// the stub cannot drift from what bridge.service.ts expects.
type InjectedBridge = NonNullable<Window['WebViewJavascriptBridge']>
type BridgeReply = Parameters<Parameters<InjectedBridge['callHandler']>[2]>[0]
type EventHandler = Parameters<InjectedBridge['registerHandler']>[1]
type EventData = Parameters<EventHandler>[0]

const eventHandlers = new Map<string, EventHandler>()

function emit (event: string, data?: unknown) {
  const handler = eventHandlers.get(event)
  if (!handler) return
  handler(data as EventData, () => {})
}

export function installBridgeStub () {
  window.WebViewJavascriptBridge = {
    callHandler (handler, data, callback) {
      // The real bridge answers asynchronously. Keeping that shape means code
      // that accidentally depends on a synchronous reply fails here too.
      //
      // mock-state describes its replies without the application's JSON types
      // so that it stays runnable on its own; the two shapes meet here.
      setTimeout(() => {
        const reply = respond(handler, data)
        callback(reply as BridgeReply)
        // The native side pushes after it has answered, and a section that
        // only listens would otherwise never hear about its own write.
        for (const { event, data: payload } of reply.events ?? []) {
          setTimeout(() => emit(event, payload), 0)
        }
      }, 0)
    },

    registerHandler (event, handler) {
      eventHandlers.set(event, handler)
    },

    disableJavscriptAlertBoxSafetyTimeout () {}
  }

  // Lets events that the native side would push be fired by hand from the
  // browser console, e.g. eqmacHarness.emit('/error', { error: 'boom' })
  window.eqmacHarness = {
    emit (event: string, data?: unknown) {
      if (!eventHandlers.has(event)) {
        console.warn(`[harness] nothing is listening on "${event}"`)
        return
      }
      emit(event, data)
    },
    events: () => [ ...eventHandlers.keys() ]
  }

  console.info('[harness] bridge stub installed')
}

declare global {
  interface Window {
    eqmacHarness?: {
      emit: (event: string, data?: unknown) => void
      events: () => string[]
    }
  }
}
