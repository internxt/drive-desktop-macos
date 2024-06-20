//
//  App.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation



enum AppError: Error {
    case runtimeError(String)
    case notImplementedError
}


enum AuthError: Error {
    case UnableToRefreshToken
    case LegacyAuthTokenNotInConfig
    case noUserFound
    case InvalidTokenExp
}
