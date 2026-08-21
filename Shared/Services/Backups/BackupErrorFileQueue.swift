//
//  BackupErrorFileQueue.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 17/8/26.
//

import Foundation

final class BackupErrorFileQueue {
    static let shared = BackupErrorFileQueue()
    private let fileURL: URL
    private let writeLock = NSLock()

    private init() {
        
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: INTERNXT_GROUP_NAME)!
        self.fileURL = container.appendingPathComponent("backup_errors.jsonl")
    }

   
    func startNewSession() {
        writeLock.lock()
        defer { writeLock.unlock() }
        try? FileManager.default.removeItem(at: fileURL)
    }

    func append(filename: String, errorMessage: String) {
        guard let data = "{\"filename\":\(jsonEscape(filename)),\"error\":\(jsonEscape(errorMessage))}\n".data(using: .utf8) else { return }
        
        writeLock.lock()
        defer { writeLock.unlock() }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: fileURL)
        }
    }


    func readAndClear() -> [(filename: String, error: String)] {
        writeLock.lock()
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            writeLock.unlock()
        }
        
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        
        return content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> (String, String)? in
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                      let filename = json["filename"],
                      let error = json["error"] else { return nil }
                return (filename, error)
            }
    }

    private func jsonEscape(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }
}
