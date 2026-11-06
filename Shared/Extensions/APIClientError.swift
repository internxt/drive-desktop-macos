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
    private static let clientVersionUnsupportedCode = "CLIENT_VERSION_UNSUPPORTED"

    var isMailNotSetUp: Bool {
        statusCode == 403 && errorCode == Self.mailNotSetUpCode
    }

    var isUpdateRequiredError: Bool {
        errorCode == Self.clientVersionUnsupportedCode
    }

    var errorCode: String? {
        guard let body = try? JSONSerialization.jsonObject(with: responseBody) as? [String: Any] else {
            return nil
        }
        return (body["errorCode"] as? String) ?? (body["code"] as? String)
    }
}
