//
//  Bool.swift
//  Toneka
//
//  Created by Romans Kisils on 15/02/2020.
//  Copyright © 2020 Romans Kisils. All rights reserved.
//

import Foundation


extension Bool {
  var cfBooleanValue: CFBoolean {
    return self ? kCFBooleanTrue : kCFBooleanFalse
  }
}
