//
//  NSSavePanelExtensions.swift
//  Toneka
//
//  Created by Romans Kisils on 20/06/2019.
//  Copyright © 2019 Romans Kisils. All rights reserved.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

extension NSSavePanel {
    func saveFile(extensions: [String]?, _ handler: @escaping (NSApplication.ModalResponse) -> Void) -> Void {
        title = "Save File"
        canCreateDirectories = true
        // An empty list means "no restriction", which is what a nil extension
        // list asked for under the old API.
        allowedContentTypes = extensions?.compactMap { UTType(filenameExtension: $0) } ?? []
        allowsOtherFileTypes = false
        begin(completionHandler: handler)
    }
}
