//
//  View.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 31/8/23.
//

import Foundation
import SwiftUI

extension View {
  public func cursor(_ cursor: NSCursor) -> some View {
    if #available(macOS 13.0, *) {
      return self.onContinuousHover { phase in
        switch phase {
        case .active:
          cursor.push()
        case .ended:
          NSCursor.pop()
        }
      }
    } else {
      return self.onHover { inside in
        if inside {
          cursor.push()
        } else {
          NSCursor.pop()
        }
      }
    }
  }
}
