//
//  AntivirusManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 20/1/25.
//

import Foundation


class AntivirusManager: ObservableObject {
    @Published var currentState: ScanState = .locked
    @Published var scannedFiles: Int = 0
    @Published var detectedFiles: Int = 0
    @Published var progress: Double = 0.0
    @Published var showAntivirus: Bool = false
    @Published var infectedFiles: [FileItem] = []
    private var scanTimer: Timer?
    private let totalScanTime: TimeInterval = 15
    private let updateInterval: TimeInterval = 0.1
    

    @MainActor
    func fetchAntivirusStatus() async {
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        
        let statusFromService = Bool.random()
        self.showAntivirus = statusFromService
        self.currentState = showAntivirus ? .options : .locked
        
    }
    
    func startScan(path: String) {

        infectedFiles = []
        currentState = .scanning
        progress = 0
        scannedFiles = 0
        detectedFiles = 0
        
        scanPathWithClamAVAndProgress(
            path: path,
            onProgress: { [weak self] scannedCount, totalFiles, lineInfo in
           
                guard let self = self else { return }
                
                let newProgress = Double(scannedCount) / Double(totalFiles) * 100.0
                
              
                if newProgress >= self.progress + 10 {
                    
               
                    DispatchQueue.main.async {
                        self.scannedFiles = scannedCount
                        self.progress += 10
                    }
                }
            },
            onInfected: { [weak self] lineInfo in
                guard let self = self else { return }
                
                let parts = lineInfo.components(separatedBy: ": ")
                if !parts.isEmpty {
                    let infectedPath = parts[0]
                    let fileItem = createFileItem(for: infectedPath)
                    
                    self.infectedFiles.append(fileItem)
                }
                
                DispatchQueue.main.async {
                    
                    self.detectedFiles += 1
                }
            },
            onComplete: { [weak self] success in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if success {
                        
                      
                    } else {
                     
                    }
                   
                    self.currentState = .results(noThreats: (self.detectedFiles == 0))
                }
            }
        )
    }
    
    func listAllFiles(in directoryPath: String) -> [String] {
        let fileManager = FileManager.default
        let baseURL = URL(fileURLWithPath: directoryPath)
        
        guard let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var files: [String] = []
        for case let fileURL as URL in enumerator {
           
            if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                files.append(fileURL.path)
            }
        }
        return files
    }
    
    func scanPathWithClamAVAndProgress(
        path: String,
        onProgress: @escaping (_ scannedCount: Int, _ totalFiles: Int, _ lineInfo: String) -> Void,
        onInfected: @escaping (_ lineInfo: String) -> Void,
        onComplete: @escaping (Bool) -> Void
    ) {
        guard let clamscanURL = Bundle.main.url(
            forResource: "clamscan",
            withExtension: nil,
            subdirectory: "ClamAVResources"
        ) else {
            appLogger.error("clamscan not found")
            onComplete(false)
            return
        }
        
        guard let mainCvdURL = Bundle.main.url(
            forResource: "daily",
            withExtension: "cvd",
            subdirectory: "ClamAVResources"
        ) else {
            appLogger.error(".cvd not found")
            onComplete(false)
            return
        }
        
        let dbDirURL = mainCvdURL.deletingLastPathComponent()
        
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        _ = fileManager.fileExists(atPath: path, isDirectory: &isDir)
        
        var allFiles: [String] = []
        if isDir.boolValue {
            allFiles = listAllFiles(in: path)
        } else {
            allFiles = [path]
        }
        
        let totalFiles = allFiles.count
        if totalFiles == 0 {
            appLogger.info("There are no files to scan")
            onComplete(true)
            return
        }
        
        let process = Process()
        process.executableURL = clamscanURL
        
        var arguments = [
            "--database=\(dbDirURL.path)",
            "--no-summary",
            "-v"
        ]
        if isDir.boolValue {
            arguments.append("-r")
        }
        arguments.append(path)
        process.arguments = arguments
        
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        
        var scannedCount = 0
        
        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else {
                return
            }
            
            let outputChunk = String(data: data, encoding: .utf8) ?? ""
            let lines = outputChunk.components(separatedBy: .newlines)
            
            for line in lines {
                guard !line.isEmpty else { continue }
                
                if line.contains("FOUND") {
                   
                    scannedCount += 1
                    onInfected(line)
                    onProgress(scannedCount, totalFiles, line)
                } else if line.contains(": ") {
                    scannedCount += 1
                    onProgress(scannedCount, totalFiles, line)
                }
            }
        }
        
        
        process.terminationHandler = { _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            
            let exitCode = process.terminationStatus
            
            DispatchQueue.main.async {
                
                onComplete(exitCode == 0)
            }
        }
        
        do {
            try process.run()
        } catch {
            appLogger.error(error.localizedDescription)
            onComplete(false)
        }
    }
    
    func createFileItem(for filePath: String) -> FileItem {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        let iconName: String
        switch fileExtension {
        // Word
        case "doc", "docx":
            iconName = "word"
            
        // Excel
        case "xls", "xlsx", "xlsm":
            iconName = "xls"
            
        // PowerPoint
        case "ppt", "pptx", "pps", "ppsx":
            iconName = "powerpoint"
            
        // Illustrator
        case "ai":
            iconName = "illustrator"
            
        // png, jpg, jpeg, gif
        case "png", "jpg", "jpeg", "gif":
            iconName = "image"
            
        default:
            iconName = "default"
        }
        
        return FileItem(iconName: iconName, fileName: fileName, extensionType: fileExtension, fullPath: filePath)
    }
    
    
    func removeInfectedFiles(_ files: [FileItem]) throws {
        let fileManager = FileManager.default
        
        for fileItem in files {
            let fileURL = URL(fileURLWithPath: fileItem.fullPath)
            try fileManager.removeItem(at: fileURL)
            appLogger.info("File delete successful : \(fileURL)")
        }
    }

}
