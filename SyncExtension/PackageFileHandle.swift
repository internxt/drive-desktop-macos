//
//  PackageFileHandle.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 2/12/25.
//

import Foundation
import AppKit
import os.log

class PackageFileHandler {
    private let tmpURL: URL
    private let logger = syncExtensionLogger
    
    init(tmpURL: URL) {
        self.tmpURL = tmpURL
    }
    
 
    func handlePackageFileIfNeeded(url: URL, realFilename: String) throws -> (processedURL: URL, isZippedPackage: Bool, zipURL: URL?) {
        
        guard isValidPackage(at: url) else {
            return (url, false, nil)
        }
        let zipURL = makeTemporaryURL("package-zip", "zip")
        let (tempPackageDir, shouldCleanup) = try prepareTempPackageDir(from: url, named: realFilename)
        
        defer {
            if shouldCleanup {
                try? FileManager.default.removeItem(at: tempPackageDir)
            }
        }
        
        
        let (process, errorPipe) = createZipProcess(
            zipPath: zipURL.path,
            packageName: realFilename,
            workingDir: tempPackageDir.deletingLastPathComponent().path
        )
        
        do {
            try process.run()
            process.waitUntilExit()
            
            try validateZipProcess(process, errorPipe, zipURL: zipURL)
            
            
            return (zipURL, true, zipURL)
        } catch {
            logger.error("❌ Error compressing package: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: zipURL)
            throw error
        }
    }
    

    
    private func isValidPackage(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let path = url.path
        
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        
        return isDirectory.boolValue && NSWorkspace.shared.isFilePackage(atPath: path)
    }
    
 
    
    private func prepareTempPackageDir(from url: URL, named packageName: String) throws -> (URL, shouldCleanup: Bool) {
        if url.lastPathComponent == packageName {
            return (url, false)
        }
        
        let tempDir = tmpURL.appendingPathComponent(packageName)
        try FileManager.default.copyItem(at: url, to: tempDir)
        
        guard FileManager.default.fileExists(atPath: tempDir.path) else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteUnknownError,
                userInfo: [NSLocalizedDescriptionKey: "Failed to copy package to temporary directory"]
            )
        }
        
        return (tempDir, true)
    }
    
    private func createZipProcess(zipPath: String, packageName: String, workingDir: String) -> (Process, Pipe) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, packageName]
        process.currentDirectoryPath = workingDir
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = nil
        
        return (process, errorPipe)
    }
    
    private func validateZipProcess(_ process: Process, _ errorPipe: Pipe, zipURL: URL) throws {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        errorPipe.fileHandleForReading.closeFile()
        
        if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
            logger.info("📦 Zip output: \(errorString)")
        }
        
        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "No error message"
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteUnknownError,
                userInfo: [NSLocalizedDescriptionKey: "Error compressing package: exit code \(process.terminationStatus). \(errorMessage)"]
            )
        }
        
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteUnknownError,
                userInfo: [NSLocalizedDescriptionKey: "Zip file was not created successfully"]
            )
        }
    }
    
    private func makeTemporaryURL(_ purpose: String, _ ext: String? = nil) -> URL {
        if let ext = ext {
            return tmpURL.appendingPathComponent("\(purpose)-\(UUID().uuidString).\(ext)")
        }
        return tmpURL.appendingPathComponent("\(purpose)-\(UUID().uuidString)")
    }
}
