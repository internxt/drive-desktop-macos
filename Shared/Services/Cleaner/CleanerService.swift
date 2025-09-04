//
//  CleanerService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//

import Foundation


class CleanerService: ObservableObject {
    // MARK: - Dependencies
    private let connectionManager: XPCConnectionManaging
    private let serviceManager: ServiceManaging
    private let dataManager = XPCDataManager()
    
    // MARK: - Published Properties
    @Published var state: XPCManagerState = .idle
    @Published var scanResult: ScanResult?
    @Published var currentFiles: [CleanupFile] = []
    @Published var currentCleaningProgress: CleanupProgress?
    @Published var cleanupResult: [CleanupResult] = []
    
    // MARK: - Private Properties
    private var currentConnection: NSXPCConnection?
    private let helperServiceName = "internxt.InternxtDesktop.cleaner.helper"
    
    // MARK: - Computed Properties
    var isConnected: Bool {
        currentConnection != nil
    }
    
    var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }
    
    var isCleaning: Bool {
        if case .cleaning = state { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }
    
    // MARK: - Initialization
    init(connectionManager: XPCConnectionManaging? = nil,
         serviceManager: ServiceManaging? = nil) {
        self.connectionManager = connectionManager ?? XPCCleanerConnectionManager(serviceName: helperServiceName)
        self.serviceManager = serviceManager ?? HelperServiceManager(serviceName: helperServiceName)
    }
    


    
    @MainActor
    func cleanupCategoriesWithProgressPolling(_ categories: [CleanupCategory],
                                           options: CleanupOptions = .default,
                                           progressHandler: @escaping @Sendable (CleanupProgress) async -> Void) async throws -> [CleanupResult] {
        
        state = .cleaning
        
        do {
            try await establishConnection()
            
            guard let helper = currentConnection?.remoteObjectProxy as? CleanerHelperXPCProtocol else {
                throw XPCManagerError.noRemoteProxy
            }
            
            let results = try await performCleanupWithPolling(helper: helper, categories: categories, options: options, progressHandler: progressHandler)
            self.cleanupResult = results
            state = .idle
            return results
            
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }
    
    @MainActor
    func scanCategories() async {
        state = .scanning
        
        do {
            try await establishConnection()
            let result = try await performScan()
            
            scanResult = result
            state = .idle
                        
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    
    @MainActor
    func cleanupWithSpecificFiles(_ cleanupData: CleanupData,
                                 options: CleanupOptions = .default,
                                 progressHandler: @escaping @Sendable (CleanupProgress) async -> Void) async throws -> [CleanupResult] {
        
        state = .cleaning
        
        do {
            try await establishConnection()
            
            guard let helper = currentConnection?.remoteObjectProxy as? CleanerHelperXPCProtocol else {
                throw XPCManagerError.noRemoteProxy
            }
            
            let cleanupDataEncoded = try dataManager.encode(cleanupData)
            let optionsData = try dataManager.encode(options)
            
            let operationId = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                helper.startCleanupWithSpecificFilesProgress(cleanupData: cleanupDataEncoded,
                                                            optionsData: optionsData) { operationId, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: operationId)
                }
            }
            
            await pollProgress(helper: helper, operationId: operationId) { progress in
                await MainActor.run {
                     self.currentCleaningProgress = progress
                     print("📊 Progress Update - Files: \(progress.processedFiles)/\(progress.totalFiles), Freed: \(progress.freedSpace) bytes, %: \(progress.percentage)")
                 }
                await progressHandler(progress)
            }
            
            let results = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CleanupResult], Error>) in
                helper.getCleanupResult(operationId: operationId) { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(throwing: XPCManagerError.decodingFailed)
                        return
                    }
                    
                    do {
                        let results = try self.dataManager.decode([CleanupResult].self, from: data)
                        self.cleanupResult = results
                        print("Polling cleanup completed: \(results)")
                        continuation.resume(returning: results)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            state = .idle
            return results
            
        } catch {
            state = .error(error.localizedDescription)
            throw error
        }
    }
    
    @MainActor
    func loadFilesForCategory(_ category: CleanupCategory) async {
        do {
            let files = try await getFilesForCategory(category)
            currentFiles = files
            print("Loaded \(files.count) files for category: \(category.name)")
        } catch {
            state = .error("Error loading files: \(error.localizedDescription)")
        }
    }
    
    func reinstallHelper() async {
        do {
            try await uninstallHelper()
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            try serviceManager.registerHelper()
            print("✅ Helper re-registered successfully")
            
            if serviceManager.getHelperStatus() == .enabled {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await scanCategories()
            }
            
        } catch {
            state = .error("Reinstall failed: \(error.localizedDescription)")
        }
    }
    
    func uninstallHelper() async throws {
        print("🚫 Uninstalling helper daemon...")
        
        do {
            try serviceManager.unregisterHelper()
            print("✅ Helper unregistered successfully")
        } catch {
            print("⚠️ Unregistration failed (might not be registered): \(error)")
            throw error
        }
    }
    
    deinit {
        connectionManager.invalidateConnection()
    }
}

// MARK: - Private Methods
private extension CleanerService {
    func establishConnection() async throws {
        // Verificar si el helper está registrado
        let helperStatus = serviceManager.getHelperStatus()
        if helperStatus != .enabled {
            print("Helper not enabled, status: \(helperStatus)")
            try serviceManager.registerHelper()
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }else {
           try serviceManager.unregisterHelper()
            try await Task.sleep(nanoseconds: 2_000_000_000) //
            try serviceManager.registerHelper()
        }
        
        guard let connection = connectionManager.createConnection() else {
            throw XPCManagerError.connectionFailed
        }
        
        currentConnection = connection
        
        // Verificar que la conexión funciona
        try await verifyConnection()
        print("✅ XPC Connection established successfully")
    }
    
    func verifyConnection() async throws {
        guard let helper = currentConnection?.remoteObjectProxy as? CleanerHelperXPCProtocol else {
            throw XPCManagerError.noRemoteProxy
        }
        
        // Test connection with a simple operation
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            helper.cancelOperation {
                continuation.resume()
            }
        }
    }
    @MainActor
    func performScan() async throws -> ScanResult {
        guard let helper = currentConnection?.remoteObjectProxy as? CleanerHelperXPCProtocol else {
            throw XPCManagerError.noRemoteProxy
        }
        
        let categories = CleanerCategories.getAllCategories()
        let options = CleanupOptions.default
        
        let categoriesData = try dataManager.encode(categories)
        let optionsData = try dataManager.encode(options)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ScanResult, Error>) in
            helper.scanCategories(categoriesData: categoriesData,
                                 optionsData: optionsData) { [weak self] data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: XPCManagerError.decodingFailed)
                    return
                }
                
                do {
                    let scanResult = try self?.dataManager.decode(ScanResult.self, from: data)
                    guard let result = scanResult else {
                        continuation.resume(throwing: XPCManagerError.decodingFailed)
                        return
                    }
                    print("Scan Result: \(result)")
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    

    

    func performCleanupWithPolling(helper: CleanerHelperXPCProtocol,
                                   categories: [CleanupCategory],
                                   options: CleanupOptions,
                                   progressHandler: @escaping @Sendable (CleanupProgress) async -> Void) async throws -> [CleanupResult] {
        
        let categoriesData = try dataManager.encode(categories)
        let optionsData = try dataManager.encode(options)
        
        let operationId = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            helper.startCleanupWithProgress(categoriesData: categoriesData,
                                           optionsData: optionsData) { operationId, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: operationId)
            }
        }
        
        print("Started cleanup operation with ID: \(operationId)")
        
        
        await pollProgress(helper: helper, operationId: operationId) { progress in
            await MainActor.run {
                self.currentCleaningProgress = progress
            }
            await progressHandler(progress)
        }
        
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CleanupResult], Error>) in
            helper.getCleanupResult(operationId: operationId) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: XPCManagerError.decodingFailed)
                    return
                }
                
                do {
                    let results = try self.dataManager.decode([CleanupResult].self, from: data)
                    print("Polling cleanup completed: \(results)")
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func pollProgress(helper: CleanerHelperXPCProtocol,
                     operationId: String,
                     progressHandler: @escaping @Sendable (CleanupProgress) async -> Void) async {
        var isCompleted = false
        var lastProgressPercentage: Double = -1
        var consecutiveNoProgress = 0
        let maxConsecutiveNoProgress = 20 
        
        print("🔍 Starting progress polling for operation: \(operationId)")
        
        while !isCompleted {
            do {
                let progressData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
                    helper.getCleanupProgress(operationId: operationId) { data, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }
                        continuation.resume(returning: data)
                    }
                }
                
                if let data = progressData {
                    let progress = try dataManager.decode(CleanupProgress.self, from: data)
                    
                    await progressHandler(progress)
                    
                    print("📊 Progress: \(progress.percentage)% - \(progress.currentFile)")
                    
                    if progress.percentage != lastProgressPercentage {
                        consecutiveNoProgress = 0
                        lastProgressPercentage = progress.percentage
                    } else {
                        consecutiveNoProgress += 1
                    }
                    
                    if progress.percentage >= 100.0 {
                        print("✅ Progress reached 100%, waiting for final results...")
                        try await Task.sleep(nanoseconds: 2_000_000_000)
                        break
                    }
                    
                } else {
                    print("📊 No progress data available yet...")
                    consecutiveNoProgress += 1
                }
                
                let resultData = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, Error>) in
                    helper.getCleanupResult(operationId: operationId) { data, error in
                        if let error = error {
                            if error.localizedDescription.contains("not found") {
                                continuation.resume(throwing: error)
                                return
                            }
                            continuation.resume(returning: nil)
                            return
                        }
                        continuation.resume(returning: data)
                    }
                }
                
                if resultData != nil {
                    print("✅ Operation \(operationId) completed - results found")
                    isCompleted = true
                    break
                }
                
                if consecutiveNoProgress >= maxConsecutiveNoProgress {
                    print("⚠️ No progress for too long, assuming completion...")
                    isCompleted = true
                    break
                }
                
           
                try await Task.sleep(nanoseconds: 500_000_000)
                
            } catch {
                print("❌ Error during polling: \(error)")
                
              
                if error.localizedDescription.contains("not found") {
                    print("❌ Operation not found, stopping polling")
                    isCompleted = true
                    break
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        print("🏁 Polling completed for operation: \(operationId)")
    }
    
    func getFilesForCategory(_ category: CleanupCategory,
                            options: CleanupOptions = .default) async throws -> [CleanupFile] {
        guard let helper = currentConnection?.remoteObjectProxy as? CleanerHelperXPCProtocol else {
            throw XPCManagerError.noRemoteProxy
        }
        
        let categoryData = try dataManager.encode(category)
        let optionsData = try dataManager.encode(options)
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CleanupFile], Error>) in
            helper.getFilesForCategory(categoryData: categoryData,
                                     optionsData: optionsData) { [weak self] data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: CleanerError.invalidData("No data received"))
                    return
                }
                
                do {
                    let files = try self?.dataManager.decode([CleanupFile].self, from: data)
                    guard let result = files else {
                        continuation.resume(throwing: XPCManagerError.decodingFailed)
                        return
                    }
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
}
