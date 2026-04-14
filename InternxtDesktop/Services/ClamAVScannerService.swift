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
            appLogger.info("Antivirus: Starting Scan with \(totalWorkers) parallel clamscan processes")
            
            var batches: [[String]] = Array(repeating: [], count: totalWorkers)
            for (index, pathStr) in paths.enumerated() {
                batches[index % totalWorkers].append(pathStr)
            }
            
            let dispatchGroup = DispatchGroup()
            var allSuccessful = true

            self.processQueue.sync { self._scanProcesses.removeAll() }
            
            var tempFilesToClean: [URL] = []
            
            for batch in batches {
                if batch.isEmpty { continue }
                
                let process = Process()
                process.executableURL = clamscanURL
                
                var arguments = ["--database=\(databaseDir.path)", "--no-summary", "-v", "-r"]
                
                let listURL = FileManager.default.temporaryDirectory.appendingPathComponent("clamscan-\(UUID().uuidString).txt")
                let listContent = batch.joined(separator: "\n")
                
                do {
                    try listContent.write(to: listURL, atomically: true, encoding: .utf8)
                    arguments.append("--file-list=\(listURL.path)")
                    tempFilesToClean.append(listURL)
                } catch {
                    appLogger.error("Failed to write to file-list, falling back to arguments: \(error)")
                    arguments.append(contentsOf: batch)
                }
                
                process.arguments = arguments
                
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                
                var lastUpdate = Date.distantPast
                var chunkScanned = 0
                var currentLineInfo = ""
                
                pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    guard !data.isEmpty else { return }
                    
                    let outputChunk = String(data: data, encoding: .utf8) ?? ""
                    let lines = outputChunk.components(separatedBy: .newlines)
                    
                    var newInfected: [String] = []
                    var localScanned = 0
                    var lastLineInfo: String?
                    
                    for line in lines {
                        guard !line.isEmpty else { continue }
                        if line.contains("FOUND") {
                            localScanned += 1
                            newInfected.append(line)
                            lastLineInfo = line
                        } else if line.contains(": ") {
                            localScanned += 1
                            lastLineInfo = line
                        }
                    }
                    
                    for infected in newInfected {
                        onInfected(infected)
                    }
                    
                    let now = Date()
                    if now.timeIntervalSince(lastUpdate) > 0.1 || !newInfected.isEmpty {
                        lastUpdate = now
                        let infoToPass = lastLineInfo ?? ""
                        let totalChunk = chunkScanned + localScanned
                        chunkScanned = 0
                        onProgress(totalChunk, infoToPass)
                    } else {
                        chunkScanned += localScanned
                        if let lInfo = lastLineInfo {
                            currentLineInfo = lInfo
                        }
                    }
                }
                
                dispatchGroup.enter()
                process.terminationHandler = { _ in
                    pipe.fileHandleForReading.readabilityHandler = nil

                    if chunkScanned > 0 {
                        onProgress(chunkScanned, currentLineInfo)
                    }

                   
                    if process.terminationStatus == 2 {
                        allSuccessful = false
                    }
                    dispatchGroup.leave()
                }

                do {
                  
                    self.processQueue.sync { self._scanProcesses.append(process) }
                    try process.run()
                } catch {
                    appLogger.error("Error executing parallel clamscan: \(error.localizedDescription)")
                    allSuccessful = false  // safe: only mutated from background thread
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                appLogger.info("Antivirus: All ClamAV parallel workers finished")
                self.processQueue.async { self._scanProcesses.removeAll() }
                
                DispatchQueue.global(qos: .background).async {
                    for tempURL in tempFilesToClean {
                        try? FileManager.default.removeItem(at: tempURL)
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
