//
//  DecryptUtils.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 2/5/24.
//

import Foundation

public struct DecryptUtils {

    public func getDecryptPassword(bucketId: String) -> String {
        let config = ConfigLoader().get()
        return "\(config.CRYPTO_SECRET2)-\(bucketId)"
    }

    public func getDecryptPassword(secret: String, bucketId: String) -> String {
        return "\(secret)-\(bucketId)"
    }

}
