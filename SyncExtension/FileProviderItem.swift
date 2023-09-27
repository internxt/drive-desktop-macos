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

class FileProviderItem: NSObject, NSFileProviderItemProtocol, NSFileProviderItemDecorating {
    private let fileProviderItemActions = FileProviderItemActionsManager()
    private let identifier: NSFileProviderItemIdentifier
    private let parentIdentifier: NSFileProviderItemIdentifier
    private let updatedAt: Date
    private let createdAt: Date
    private let itemExtension: String?
    private let itemType: RemoteItemType
    private let isAvailableOffline: Bool
    var filename: String
    var documentSize: NSNumber?
    
    public static func parentIdIsRootFolder(identifier: NSFileProviderItemIdentifier) -> Bool {
        return identifier == .rootContainer
    }
    
    static let decorationPrefix = Bundle.main.bundleIdentifier!

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
        self.isAvailableOffline = fileProviderItemActions.isAvailableOffline(identifier: self.identifier) == true
    }
    
    var itemIdentifier: NSFileProviderItemIdentifier {
        return identifier
    }
    
    var creationDate: Date? {
        return self.createdAt
    }
    
    var contentModificationDate: Date? {
        // We should use here something like contentModificationDate from the backend
        // since this doesn't exists yet, we'll fallback to the creation date
        // NOTE: We cannot use updatedAt field here, cause that field is modified
        // with renames, trashing etc, this date is the date of the LAST CONTENT MODIFICATION
        return self.createdAt
    }
    
    @available(macOSApplicationExtension 13.0, *)
    var contentPolicy: NSFileProviderContentPolicy {
        if isAvailableOffline {
            return .downloadEagerlyAndKeepDownloaded
        }
        return .inherited
    }
    
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        return self.parentIdentifier
    }
    
    
    var decorations: [NSFileProviderItemDecorationIdentifier]? {
        var decorations = [NSFileProviderItemDecorationIdentifier]()
    
        if  isAvailableOffline {
            decorations.append(NSFileProviderItemDecorationIdentifier(rawValue: "availableOffline"))
            decorations.append(NSFileProviderItemDecorationIdentifier(rawValue: "folderAvailableOffline"))
        }
        
        return decorations
    }
    
    var userInfo: [AnyHashable : Any]? {
        return ["availableOffline": isAvailableOffline]
    }
    
    var capabilities: NSFileProviderItemCapabilities {
        
        if parentIdentifier == .trashContainer {
            return [.allowsDeleting]
        }
        
        return [            
            .allowsAddingSubItems,
            .allowsContentEnumerating,
            .allowsTrashing,
            .allowsReading,
            .allowsRenaming,
            .allowsReparenting,
        ]
    }
    
   
    
    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(
            contentVersion: Data("STATIC".utf8),
            metadataVersion: Data("STATIC_\(filename)_\(isAvailableOffline ? "offline" : "online")".utf8)
        )
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
