import { Injectable } from '@angular/core'
import { Bridge } from './bridge.service'

export type JSONEncodable = null | boolean | number | string | JSONData
export interface JSONData {
  [key: string]: JSONEncodable | JSONEncodable[]
}
export interface RequestOptions {
  method: 'GET' | 'POST' | 'DELETE' | 'OPTIONS'
  endpoint?: string
  data?: JSONData
}

type EventCallback = (data?: any) => void
@Injectable({
  providedIn: 'root'
})
export class DataService {
  route = ''

  async request (opts: RequestOptions): Promise<any> {
    if (opts.endpoint && opts.endpoint[0] !== '/') opts.endpoint = `/${opts.endpoint}`
    const args: [string, any?] = [ `${opts.method} ${this.route}${opts.endpoint || ''}`, opts.data ]
    let resp
    try {
      resp = await Bridge.call(...args)
    } catch (err) {
      console.error(`${args[0]} failed`, err)
      throw err
    }
    return resp
  }

  private normalizeEventCallback (
    eventOrCallback: string | EventCallback,
    callback?: EventCallback
  ): { event: string, callback: EventCallback } {
    const event = typeof eventOrCallback === 'string' ? eventOrCallback : ''
    return {
      event,
      // The overloads admit only (callback) or (event, callback), so by here
      // one of the two is a function.
      callback: typeof eventOrCallback === 'function' ? eventOrCallback : callback!
    }
  }

  async on (callback: EventCallback): Promise<void>
  async on (event: string, callback: EventCallback): Promise<void>
  async on (eventOrCallback: string | EventCallback, cb?: EventCallback) {
    const { event, callback } = this.normalizeEventCallback(eventOrCallback, cb)
    Bridge.on(`${this.route}${event}`, callback)
  }

  async off (callback: EventCallback): Promise<void>
  async off (event: string, callback: EventCallback): Promise<void>
  async off (eventOrCallback: string | EventCallback, cb?: EventCallback) {
    const { event, callback } = this.normalizeEventCallback(eventOrCallback, cb)
    Bridge.off(`${this.route}${event}`, callback)
  }
}
