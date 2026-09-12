//
//  Console.swift
//  Toneka
//
//  Created by Roman Kisil on 29/04/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation

class Console {
  /// Where every line ends up. Opened from the settings sheet.
  static let fileURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Logs/Toneka.log")

  /// The file is started over once it reaches this, keeping the previous run
  /// in Toneka.log.old. The app stays running for weeks, so the file would
  /// otherwise grow without bound.
  private static let rotateAt: UInt64 = 2 * 1024 * 1024

  private static let fileQueue = DispatchQueue(label: "Toneka.Console.file")
  private static let fileHandle: FileHandle? = {
    let manager = FileManager.default
    let path = fileURL.path
    if let size = (try? manager.attributesOfItem(atPath: path))?[.size] as? UInt64, size >= rotateAt {
      let old = fileURL.deletingPathExtension().appendingPathExtension("log.old")
      try? manager.removeItem(at: old)
      try? manager.moveItem(at: fileURL, to: old)
    }
    if !manager.fileExists(atPath: path) {
      manager.createFile(atPath: path, contents: nil)
    }
    let handle = try? FileHandle(forWritingTo: fileURL)
    handle?.seekToEndOfFile()
    return handle
  }()
  private static let timestamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
  }()

  static func log (_ somethings: Any..., fileAbsolutePath: String = #file, line: Int = #line) {
    write("INFO ", somethings, fileAbsolutePath, line)
  }

  /// Something failed. Same destinations as `log`, tagged so the file can be
  /// searched for failures alone.
  static func error (_ somethings: Any..., fileAbsolutePath: String = #file, line: Int = #line) {
    write("ERROR", somethings, fileAbsolutePath, line)
  }

  // NSLog rather than print: print buffers when stdout is not a terminal, so
  // logs from a GUI launch were lost unless the process exited cleanly.
  //
  // NSLog reaches the unified log, but every %@ argument is stored there as
  // <private>, so `log show` cannot read these lines back after the fact. The
  // file is what survives a GUI launch; ~/Library/Logs is where Console.app
  // lists it.
  private static func write (_ level: String, _ somethings: [Any], _ fileAbsolutePath: String, _ line: Int) {
    let file = fileAbsolutePath[fileAbsolutePath.range(of: "/app/")!.upperBound...]
    let message = somethings.map { ($0 as AnyObject).debugDescription }.joined(separator: " ")
    NSLog("Toneka %@ (%@:%d) %@", level, String(file), line, message)

    let entry = "\(timestamp.string(from: Date())) \(level) (\(file):\(line)) \(message)\n"
    fileQueue.async {
      fileHandle?.write(entry.data(using: .utf8)!)
    }
  }
}
