//
//  String.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 31/8/23.
//

import Foundation
extension String {
    var unicode: String {
        guard let code = UInt32(self, radix: 16),
              let scalar = Unicode.Scalar(code) else {
            return ""
        }
        return "\(scalar)"
    }
}
