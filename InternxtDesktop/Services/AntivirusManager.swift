//
//  AntivirusManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 20/1/25.
//

import Foundation
import InternxtSwiftCore
import SwiftUI

class AntivirusManager: ObservableObject {
    @Published var currentState: ScanState = .locked
    @Published var scannedFiles: Int = 0
    @Published var detectedFiles: Int = 0
    @Published var progress: Double = 0.0
    @Published var totalFiles: Int = 0
    @Published var isCalculatingTotal: Bool = false
    @Published var showAntivirus: Bool = false
    @Published var infectedFiles: [FileItem] = []
    @Published var selectedPath: String = ""
    
    private let scanner = ClamAVScannerService()
    private let database = ClamAVDatabaseService.shared
    
    private var isCancelled = false
    
    @MainActor
    func fetchAntivirusStatus() async {
        appLogger.info("Antivirus Information")
        if self.currentState == .scanning {
            if !FeaturesService.shared.antivirusEnabled {
                cancelScan(isLocked: true)
            }
        } else {
            self.currentState = FeaturesService.shared.antivirusState
        }
    }
    
    @MainActor
    func startScan(path: String) {
        infectedFiles = []
        currentState = .scanning
        progress = 0
        scannedFiles = 0
        detectedFiles = 0
        totalFiles = 0
        isCalculatingTotal = true
        isCancelled = false
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            if !isDir.boolValue {
                self.totalFiles = 1
                self.isCalculatingTotal = false
            } else {
                countFilesInBackground(path: path)
            }
        }
        
        var pathsToScan: [String] = [path]
        if isDir.boolValue, let contents = try? fileManager.contentsOfDirectory(atPath: path) {
            pathsToScan = contents.map { (path as NSString).appendingPathComponent($0) }
        }
        
        scanner.scanPathsInParallel(
            paths: pathsToScan,
            onProgress: { [weak self] newFilesScanned, lineInfo in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.scannedFiles += newFilesScanned
                    if !self.isCalculatingTotal {
                        if self.totalFiles <= 0 { self.totalFiles = self.scannedFiles + 1000 }
                        if self.scannedFiles > self.totalFiles { self.totalFiles = self.scannedFiles + 1000 }
                        self.progress = min((Double(self.scannedFiles) / Double(self.totalFiles)) * 100.0, 99.0)
                    }
                    if !lineInfo.isEmpty { self.selectedPath = lineInfo }
                }
            },
            onInfected: { [weak self] lineInfo in
                guard let self = self else { return }
                let parts = lineInfo.components(separatedBy: ": ")
                if !parts.isEmpty {
                    let infectedPath = parts[0]
                    let fileItem = self.createFileItem(for: infectedPath)
                    DispatchQueue.main.async {
                        self.infectedFiles.append(fileItem)
                        self.detectedFiles += 1
                        self.selectedPath = infectedPath
                    }
                }
            },
            onComplete: { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isCalculatingTotal = false
                    self.progress = 100.0
                    self.currentState = .results(noThreats: (self.detectedFiles == 0))
                    if let resolvedURL = BookmarkManager.shared.resolveBookmark() {
                        BookmarkManager.shared.stopAccessing(url: resolvedURL)
                    }
                }
            }
        )
    }
    
    @MainActor
    func cancelScan(isLocked: Bool = false) {
        isCancelled = true
        scanner.cancelAll()
        self.currentState = isLocked ? .locked : .results(noThreats: (self.detectedFiles == 0))
        if let resolvedURL = BookmarkManager.shared.resolveBookmark() {
            BookmarkManager.shared.stopAccessing(url: resolvedURL)
        }
    }
    
    func downloadDatabases() {
        database.downloadDatabasesIfNeeded(currentState: currentState)
    }
    
   func removeInfectedFiles(_ files: [FileItem]) throws {
        let fileManager = FileManager.default
        for fileItem in files {
            let fileURL = URL(fileURLWithPath: fileItem.fullPath)
            try fileManager.removeItem(at: fileURL)
            appLogger.info("File delete successful : \(fileURL)")
        }
    }
    
    func createFileItem(for filePath: String) -> FileItem {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        let iconName: String
        switch fileExtension {
        case "doc", "docx":                 iconName = "word"
        case "xls", "xlsx", "xlsm":         iconName = "xls"
        case "ppt", "pptx", "pps", "ppsx":  iconName = "powerpoint"
        case "ai":                           iconName = "illustrator"
        case "png", "jpg", "jpeg", "gif":   iconName = "image"
        default:                             iconName = "default"
        }
        return FileItem(iconName: iconName, fileName: fileName, extensionType: fileExtension, fullPath: filePath)
    }
    
    @MainActor
    func showAlert(message: String, informativeText: String? = nil, style: NSAlert.Style = .informational, buttonTitle: String = "OK") {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText ?? ""
        alert.alertStyle = style
        alert.addButton(withTitle: buttonTitle)
        alert.runModal()
    }
    
 
    
    private func countFilesInBackground(path: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let url = URL(fileURLWithPath: path)
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) {
                var count = 0
                while enumerator.nextObject() != nil {
                    if self.isCancelled { return }
                    count += 1
                }
                DispatchQueue.main.async {
                    if !self.isCancelled {
                        self.totalFiles = max(count, 1)
                        self.isCalculatingTotal = false
                        appLogger.info("Antivirus: Total files calculated for scan: \(self.totalFiles)")
                    }
                }
            } else {
                DispatchQueue.main.async { self.isCalculatingTotal = false }
            }
        }
    }
}
