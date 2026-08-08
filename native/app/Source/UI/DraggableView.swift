//
//  DraggableView.swift
//  Toneka
//
//  Created by Romans Kisils on 13/07/2019.
//  Copyright © 2019 Romans Kisils. All rights reserved.
//

import Foundation
import Cocoa

class DraggableView: NSView {
    override func mouseDragged(with event: NSEvent) {
      event.window?.performDrag(with: event)
    }
}
