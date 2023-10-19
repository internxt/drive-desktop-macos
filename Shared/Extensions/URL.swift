//
//  URL.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 19/9/23.
//

import Foundation
import SwiftUI

struct URLFileAttribute {
    private(set) var fileSize: UInt? = nil
    private(set) var creationDate: Date? = nil
    private(set) var modificationDate: Date? = nil

    init(url: URL) {
        let path = url.path
        guard let dictionary: [FileAttributeKey: Any] = try? FileManager.default
                .attributesOfItem(atPath: path) else {
            return
        }

        if dictionary.keys.contains(FileAttributeKey.size),
            let value = dictionary[FileAttributeKey.size] as? UInt {
            self.fileSize = value
        }

        if dictionary.keys.contains(FileAttributeKey.creationDate),
            let value = dictionary[FileAttributeKey.creationDate] as? Date {
            self.creationDate = value
        }

        if dictionary.keys.contains(FileAttributeKey.modificationDate),
            let value = dictionary[FileAttributeKey.modificationDate] as? Date {
            self.modificationDate = value
        }
    }
}

extension URL {
    func open() {
        NSWorkspace.shared.open(self)
    }
    
    public func directoryContents() -> [URL] {
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil)
                return directoryContents
            } catch let error {
                print("Error while getting directory content: \(error)")
                return []
            }
        }

      public func getFolderSize() -> UInt {
            let contents = self.directoryContents()
            var totalSize: UInt = 0
            contents.forEach { url in
                let size = url.getFileSize()
                totalSize += size
            }
            return totalSize
        }

        public func getFileSize() -> UInt {
            let attributes = URLFileAttribute(url: self)
            return attributes.fileSize ?? 0
        }
}
