//
//  Console.swift
//  Toneka
//
//  Created by Roman Kisil on 29/04/2018.
//  Copyright © 2018 Roman Kisil. All rights reserved.
//

import Foundation

class Console {
  // NSLog rather than print: print buffers when stdout is not a terminal, so
  // logs from a GUI launch were lost unless the process exited cleanly. NSLog
  // also lands in the unified log, which survives the process entirely.
  static func log (_ somethings: Any..., fileAbsolutePath: String = #file, line: Int = #line) {
    let file = fileAbsolutePath[fileAbsolutePath.range(of: "/app/")!.upperBound...]
    let message = somethings.map { ($0 as AnyObject).debugDescription }.joined(separator: " ")
    NSLog("Toneka (%@:%d) %@", String(file), line, message)
  }
}

