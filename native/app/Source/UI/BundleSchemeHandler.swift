//
//  BundleSchemeHandler.swift
//  eqMac
//
//  Serves the unpacked interface over a scheme of our own so the page gets a
//  real origin.
//
//  Loaded from file:// the page has an opaque origin, and a module script --
//  which is all Angular emits -- is fetched with CORS and always fails against
//  one. The way around that was to switch off file:// isolation for the whole
//  web view, which let the page read any file the user can. A custom scheme
//  removes the need: modules load normally and nothing outside the directory
//  below is reachable.
//

import Foundation
import WebKit
import Shared

final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
  static let scheme = "eqmac"
  static let host = "ui"

  /// Everything served comes from inside this directory.
  private let root: URL

  init (root: URL) {
    self.root = root.standardizedFileURL
  }

  static func url (forPath path: String) -> URL {
    return URL(string: "\(scheme)://\(host)/\(path)")!
  }

  func webView (_ webView: WKWebView, start task: WKURLSchemeTask) {
    guard let requestURL = task.request.url, let file = resolve(requestURL) else {
      // Worth saying out loud: the interface asked for something outside the
      // directory, which means either a bad path or a build that moved files.
      Console.log("Refused \(task.request.url?.absoluteString ?? "a request") from the UI bundle")
      task.didFailWithError(URLError(.badURL))
      return
    }

    guard let data = try? Data(contentsOf: file) else {
      Console.log("UI bundle is missing \(file.lastPathComponent)")
      task.didFailWithError(URLError(.fileDoesNotExist))
      return
    }

    let response = HTTPURLResponse(
      url: requestURL,
      statusCode: 200,
      httpVersion: "HTTP/1.1",
      headerFields: [
        "Content-Type": BundleSchemeHandler.contentType(of: file),
        "Content-Length": String(data.count)
      ]
    )!

    task.didReceive(response)
    task.didReceive(data)
    task.didFinish()
  }

  func webView (_ webView: WKWebView, stop task: WKURLSchemeTask) {}

  /// Maps a request onto a file inside `root`, refusing anything that climbs
  /// out of it. The path arrives from the page, so `..` must not escape.
  private func resolve (_ url: URL) -> URL? {
    guard url.host == BundleSchemeHandler.host else { return nil }

    let path = url.path.isEmpty || url.path == "/" ? "/index.html" : url.path
    let candidate = root.appendingPathComponent(path).standardizedFileURL

    guard candidate.path.hasPrefix(root.path + "/") else { return nil }
    return candidate
  }

  private static func contentType (of file: URL) -> String {
    switch file.pathExtension.lowercased() {
    case "html": return "text/html; charset=utf-8"
    case "js", "mjs": return "text/javascript; charset=utf-8"
    case "css": return "text/css; charset=utf-8"
    case "json", "webmanifest": return "application/json; charset=utf-8"
    case "txt": return "text/plain; charset=utf-8"
    case "svg": return "image/svg+xml"
    case "png": return "image/png"
    case "jpg", "jpeg": return "image/jpeg"
    case "ico": return "image/x-icon"
    case "woff2": return "font/woff2"
    case "woff": return "font/woff"
    default: return "application/octet-stream"
    }
  }
}
