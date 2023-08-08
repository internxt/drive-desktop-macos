//
//  FileProviderItem.swift
//  SyncExtension
//
//  Created by Robert Garcia on 30/7/23.
//

import FileProvider
import UniformTypeIdentifiers

public enum RemoteItemType: String {
    case file
    case folder
}



struct RemoteItem {
    public let id: String
    public let type: RemoteItemType
}

class FileProviderItem: NSObject, NSFileProviderItem {

    // TODO: implement an initializer to create an item from your extension's backing model
    // TODO: implement the accessors to return the values from your extension's backing model
    
    private let identifier: NSFileProviderItemIdentifier
    private let parentIdentifier: NSFileProviderItemIdentifier
    private let updatedAt: Date
    private let createdAt: Date
    private let itemExtension: String?
    private let itemType: RemoteItemType
    var filename: String
    init(identifier: NSFileProviderItemIdentifier, filename: String, parentId: NSFileProviderItemIdentifier, createdAt: Date, updatedAt:Date, itemExtension: String?, itemType: RemoteItemType) {
        self.identifier = identifier
        self.filename = filename
        self.parentIdentifier = parentId
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.itemExtension = itemExtension
        self.itemType = itemType
    }
    
    var itemIdentifier: NSFileProviderItemIdentifier {
        return identifier
    }
    
    var contentPolicy: NSFileProviderContentPolicy {
        return .inherited
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        return self.parentIdentifier
    }
    
    var capabilities: NSFileProviderItemCapabilities {
        return [.allowsReading, .allowsWriting, .allowsRenaming, .allowsReparenting, .allowsTrashing, .allowsDeleting]
    }
    
   
    
    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(contentVersion: Data("content".utf8), metadataVersion: Data("metadata".utf8))
    }
    
    var contentType: UTType {
        if(self.itemType == RemoteItemType.folder) {
            return .folder
        }
        
        guard let itemExtension = self.itemExtension else {
            return UTType.plainText
        }
        
        return UTType(itemExtension) ?? UTType.plainText
    }
}
