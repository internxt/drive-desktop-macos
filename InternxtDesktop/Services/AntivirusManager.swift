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
      private var scanTimer: Timer?
      private let totalScanTime: TimeInterval = 15
      private let updateInterval: TimeInterval = 0.1
      
      func startScan() {
          currentState = .scanning
          progress = 0
          scannedFiles = 0
          detectedFiles = 0
          
          scanTimer?.invalidate()
          
          let totalSteps = totalScanTime / updateInterval
          let progressIncrement = 1.0 / totalSteps
          
          scanTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
              guard let self = self else { return }
              
              if self.progress < 1.0 {
                  self.progress += progressIncrement
                  self.scannedFiles += 50
                  self.detectedFiles = Int.random(in: 0...1)
              } else {
                  timer.invalidate()
                  self.currentState = .results(noThreats: self.detectedFiles == 0)
              }
          }
      }
      

    @MainActor
    func fetchAntivirusStatus() async {
       
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
      
        let statusFromService = Bool.random()
        self.showAntivirus = statusFromService
        self.currentState = showAntivirus ? .options : .locked
        
    }
    
    
    
    func startScan(path: String) {
        currentState = .scanning
        progress = 0
        scannedFiles = 0
        detectedFiles = 0
        
      
        scanPathWithClamAVAndProgress(
            path: path,
            onProgress: { [weak self] scannedFile in
                DispatchQueue.main.async {
                    self?.scannedFiles += 1
                    self?.progress += 1.0 / Double(self?.scannedFiles ?? 1)
                }
            },
            onInfected: { [weak self] infectedFile in
                DispatchQueue.main.async {
                    self?.detectedFiles += 1
                }
            },
            onComplete: { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.currentState = self?.detectedFiles == 0 ? .results(noThreats: true) : .results(noThreats: false)
                    } else {
                     
                    }
                }
            }
        )
    }
    
    
    func scanPathWithClamAVAndProgress(
          path: String,
          onProgress: @escaping (String) -> Void,
          onInfected: @escaping (String) -> Void,
          onComplete: @escaping (Bool) -> Void
      ) {
         
          guard let clamscanURL = Bundle.main.url(
              forResource: "clamscan",
              withExtension: nil,
              subdirectory: "ClamAVResources"
          ) else {
              print("No se encontró clamscan en el bundle.")
              onComplete(false)
              return
          }

         
          guard let mainCvdURL = Bundle.main.url(
              forResource: "daily",
              withExtension: "cvd",
              subdirectory: "ClamAVResources"
          ) else {
              print("No se encontró main.cvd en ClamAVResources.")
              onComplete(false)
              return
          }

          let dbDirURL = mainCvdURL.deletingLastPathComponent()

        
          let process = Process()
          process.executableURL = clamscanURL

          let fileManager = FileManager.default
          var isDirectory: ObjCBool = false
          if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
              process.arguments = ["--database=\(dbDirURL.path)", "-r", path]
          } else {
              process.arguments = ["--database=\(dbDirURL.path)", path]
          }

        
          let pipe = Pipe()
          process.standardOutput = pipe
          process.standardError = pipe

          let fileHandle = pipe.fileHandleForReading

          DispatchQueue.global().async {
              let data = fileHandle.readDataToEndOfFile()
              if let output = String(data: data, encoding: .utf8) {
                  output.split(separator: "\n").forEach { line in
                      let lineString = String(line)
                      print(lineString)
                      if lineString.contains("FOUND") {
                          onInfected(lineString)
                      } else if lineString.contains(": OK") || lineString.contains(": ") {
                          let scannedFile = lineString.split(separator: ":")[0]
                          onProgress(String(scannedFile))
                      }
                  }
              }

              DispatchQueue.main.async {
                  let status = process.terminationStatus
                  onComplete(status == 0)
              }
          }

          do {
              try process.run()
          } catch {
              print("Error al ejecutar clamscan: \(error.localizedDescription)")
              onComplete(false)
          }
      }
  }
