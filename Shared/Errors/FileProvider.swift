//
//  FileProvider.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 22/8/23.
//

import Foundation


enum FileProviderError: Error {
    case CannotOpenVisibleUrl
    case DomainNotLoaded
    case CannotGetFileProviderManager
}
