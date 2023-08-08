//
//  EnumerateFolderItemsUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 7/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
struct EnumerateFolderItemsUseCase {
    private let observer: NSFileProviderChangeObserver
    private let anchor: NSFileProviderSyncAnchor
    private let driveAPI: DriveAPI = APIFactory.Drive
    
    init(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        self.observer = observer
        self.anchor = anchor
    }
    
    public func run() {
        
    }
}

