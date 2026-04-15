//
//  ClamAVScannerService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 1/4/26.
//

import Foundation
import InternxtSwiftCore

class ClamAVScannerService {
    
    private let processQueue = DispatchQueue(label: "com.internxt.clamav.processQueue")
    private var _scanProcesses: [Process] = []

    var scanProcesses: [Process] {
        processQueue.sync { _scanProcesses }
    }


    func scanPathsInParallel(
        paths: [String],
        onProgress: @escaping (_ newFilesScanned: Int, _ lineInfo: String) -> Void,
        onInfected: @escaping (_ lineInfo: String) -> Void,
        onComplete: @escaping (_ success: Bool) -> Void
    ) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            guard let clamscanURL = Bundle.main.url(
                forResource: "clamscan",
                withExtension: nil,
                subdirectory: "ClamAVResources"
            ) else {
                appLogger.error("clamscan not found")
                onComplete(false)
                return
            }
            
            let databaseDir = ClamAVDatabaseService.shared.databaseDir
            
            guard FileManager.default.fileExists(atPath: databaseDir.path) else {
                appLogger.error("DB Directory not found: \(databaseDir.path)")
                onComplete(false)
                return
            }
            
            let totalWorkers = self.calculateOptimalWorkers(pathCount: paths.count)
            appLogger.info("Antivirus: Starting scan with \(totalWorkers) workers for \(paths.count) files")

            var batches: [[String]] = Array(repeating: [], count: totalWorkers)
            for (index, path) in paths.enumerated() {
                batches[index % totalWorkers].append(path)
            }

            let dispatchGroup = DispatchGroup()
            let successLock = NSLock()
            let tempFilesLock = NSLock()
            var allSuccessful = true
            var tempFilesToClean: [URL] = []

            self.processQueue.sync { self._scanProcesses.removeAll() }

            for batch in batches where !batch.isEmpty {
                let listURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("clamscan-\(UUID().uuidString).txt")

                do {
                    try batch.joined(separator: "\n").write(to: listURL, atomically: true, encoding: .utf8)
                    tempFilesLock.withLock {
                        tempFilesToClean.append(listURL)
                    }
                } catch {
                    appLogger.error("Cannot write file-list, skipping batch: \(error)")
                    successLock.withLock { allSuccessful = false }
                    continue
                }

                let process = Process()
                process.executableURL = clamscanURL
                process.arguments = [
                    "--database=\(databaseDir.path)",
                    "--no-summary",
                    "-v",
                    "-r",
                    "--file-list=\(listURL.path)"
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                let bufferLock = NSLock()
                var lineBuffer = ""
                var lastProgressUpdate = Date.distantPast
                var pendingScanned = 0
                var pendingLineInfo = ""

                pipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
                    let data = fileHandle.availableData
                    
                    guard !data.isEmpty else {
                        fileHandle.readabilityHandler = nil
                        return
                    }

                    bufferLock.withLock {
                        lineBuffer += String(data: data, encoding: .utf8) ?? ""

                        while let newlineRange = lineBuffer.range(of: "\n") {
                            let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
                            lineBuffer.removeSubrange(lineBuffer.startIndex...newlineRange.lowerBound)

                            let trimmed = line.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { continue }

                            if line.hasSuffix(": FOUND") {
                                pendingScanned += 1
                                pendingLineInfo = line
                                DispatchQueue.main.async { onInfected(line) }
                            } else if line.hasSuffix(": OK") || line.hasSuffix(": Empty file") || line.hasSuffix(": Symbolic link") {
                                pendingScanned += 1
                                pendingLineInfo = line
                            }
                        }
                        let now = Date()
                        if now.timeIntervalSince(lastProgressUpdate) >= 0.1 && pendingScanned > 0 {
                            lastProgressUpdate = now
                            let count = pendingScanned
                            let info = pendingLineInfo
                            pendingScanned = 0
                            DispatchQueue.main.async { onProgress(count, info) }
                        }
                    }
                }
                
                dispatchGroup.enter()
                process.terminationHandler = { [weak self] proc in
        
                    pipe.fileHandleForReading.readabilityHandler = nil
                    
                    bufferLock.withLock {
                        if !lineBuffer.trimmingCharacters(in: .whitespaces).isEmpty {
                            let remaining = lineBuffer
                            if remaining.hasSuffix(": FOUND") {
                                DispatchQueue.main.async { onInfected(remaining) }
                            }
                            pendingScanned += 1
                            pendingLineInfo = remaining
                        }

                        if pendingScanned > 0 {
                            let count = pendingScanned
                            let info = pendingLineInfo
                            DispatchQueue.main.async { onProgress(count, info) }
                        }
                    }

                    if proc.terminationStatus == 2 {
                        appLogger.error("clamscan exited with error (status 2)")
                        successLock.withLock { allSuccessful = false }
                    }

                    dispatchGroup.leave()
                }

                do {
                  
                    self.processQueue.sync { self._scanProcesses.append(process) }
                    try process.run()
                } catch {
                    appLogger.error("Failed to launch clamscan: \(error.localizedDescription)")
                    pipe.fileHandleForReading.readabilityHandler = nil
                    successLock.withLock { allSuccessful = false }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) { [weak self] in
                appLogger.info("Antivirus: All ClamAV parallel workers finished")
                guard let self = self else { return }
                
                self.processQueue.async { self._scanProcesses.removeAll() }
                
                let urlsToClean = tempFilesLock.withLock { tempFilesToClean }
                DispatchQueue.global(qos: .background).async {
                    for url in urlsToClean {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                
                onComplete(allSuccessful)
            }
        }
    }
    
    func cancelAll() {
        let toTerminate: [Process] = processQueue.sync {
            let list = _scanProcesses
            _scanProcesses.removeAll()
            return list
        }
        for process in toTerminate where process.isRunning {
            process.terminate()
        }
    }

    

    private func calculateOptimalWorkers(pathCount: Int) -> Int {
        let maxWorkersLimit = 3
        let physicalMemoryGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        
        let ramWorkers: Int
        if physicalMemoryGB > 32 {
            ramWorkers = 3 
        } else if physicalMemoryGB >= 24 {
            ramWorkers = 2
        } else {
            ramWorkers = 1
        }
        
        let cpuWorkers = ProcessInfo.processInfo.activeProcessorCount
        let optimalWorkers = min(maxWorkersLimit, ramWorkers, cpuWorkers, pathCount)
        return max(1, optimalWorkers)
    }
}
