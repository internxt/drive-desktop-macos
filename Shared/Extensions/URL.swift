//
//  URL.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 19/9/23.
//

import Foundation
import SwiftUI

extension URL {
    func open() {
        NSWorkspace.shared.open(self)
    }
}
