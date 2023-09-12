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
    
    private let identifier: NSFileProviderItemIdentifier
    private let parentIdentifier: NSFileProviderItemIdentifier
    private let updatedAt: Date
    private let createdAt: Date
    private let itemExtension: String?
    private let itemType: RemoteItemType
    var filename: String
    var documentSize: NSNumber?
    
    public static func parentIdIsRootFolder(identifier: NSFileProviderItemIdentifier) -> Bool {
        return identifier == .rootContainer
    }
    public static func getFilename(name: String, itemExtension: String?) -> String {
        if itemExtension == nil {
            return name
        }
        
        return "\(name).\(itemExtension?.lowercased() ?? "")"
    }
    
    // TODO: Overload this to provide a faster way to initialize an NSFileProviderItem, this seems too verbose
    init(identifier: NSFileProviderItemIdentifier, filename: String, parentId: NSFileProviderItemIdentifier, createdAt: Date, updatedAt:Date, itemExtension: String?, itemType: RemoteItemType, size: Int = 0) {
        self.identifier = identifier
        self.filename = filename
        self.parentIdentifier = parentId
        self.updatedAt = updatedAt
        self.createdAt = createdAt
        self.itemExtension = itemExtension?.lowercased()
        self.itemType = itemType
        self.documentSize = NSNumber(value: size)
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
        
        if parentIdentifier == .trashContainer {
            return [.allowsDeleting]
        }
        
        return [.allowsReading, .allowsWriting, .allowsRenaming, .allowsReparenting, .allowsTrashing]
    }
    
   
    
    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(contentVersion: Data("STATIC".utf8), metadataVersion: Data("STATIC_\(filename)".utf8))
    }

    
    var contentType: UTType {
        
        if(self.itemType == RemoteItemType.folder) {
            return .folder
        }
                
        guard let itemExtension = self.itemExtension else {
            return UTType.plainText
        }
        
        return UTType(tag: itemExtension, tagClass: .filenameExtension, conformingTo: nil) ?? UTType.plainText
    }
}
