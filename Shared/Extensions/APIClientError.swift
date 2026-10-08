//
//  APIClientError.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 17/09/2026.
//

import Foundation
import InternxtSwiftCore

extension APIClientError {

    private static let mailNotSetUpCode = "MAIL_NOT_SETUP"

    var isMailNotSetUp: Bool {
        statusCode == 403 && errorCode == Self.mailNotSetUpCode
    }

    var errorCode: String? {
        guard let body = try? JSONSerialization.jsonObject(with: responseBody) as? [String: Any] else {
            return nil
        }
        return body["code"] as? String
    }
}
