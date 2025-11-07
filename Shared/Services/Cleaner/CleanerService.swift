//
//  CleanerService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//

import SwiftUI
import OSLog
import Combine

let cleanerLogger = LogService.shared.createLogger(subsystem: .Cleaner, category: "Cleaner")

class CleanerService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var state: CleanerState = .idle
    @Published var scanResult: ScanResult?
    @Published var currentFiles: [CleanupFile] = []
    @Published var cleanupResult: [CleanupResult] = []
    @Published var currentCleaningProgress: CleanupProgress?
    @Published var isCancelling: Bool = false
    @Published var viewState: CleanerViewState = .locked
    
    private let connectionService: XPCConnectionService
    private let helperService: HelperManagementService
    private let scanService: ScanOperationService
    private let cleanupService: CleanupOperationService
    
    private var cancellables = Set<AnyCancellable>()
    private var _cleanupViewModel: CleanupViewModel?
    
    // MARK: - Computed Properties
    @MainActor
    var cleanupViewModel: CleanupViewModel {
        if _cleanupViewModel == nil {
            _cleanupViewModel = CleanupViewModel(cleanerService: self)
        }
        return _cleanupViewModel!
    }
    
    var isConnected: Bool {
        connectionService.isConnected
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
    
    var canCancelOperation: Bool {
        return isCleaning || isScanning
    }
    
    // MARK: - Initialization
    init(
        connectionService: XPCConnectionService? = nil,
        helperService: HelperManagementService? = nil,
        scanService: ScanOperationService? = nil,
        cleanupService: CleanupOperationService? = nil
    ) {
        self.connectionService = connectionService ?? XPCConnectionService()
        self.helperService = helperService ?? HelperManagementService()
        self.scanService = scanService ?? ScanOperationService(connectionService: self.connectionService)
        self.cleanupService = cleanupService ?? CleanupOperationService(connectionService: self.connectionService)
        
        setupBindings()
    }
    
    deinit {
        cleanup()
    }
    
    private func cleanup() {
        connectionService.invalidateConnection()
    }
    
    private func setupBindings() {
        // View state observers
        $currentCleaningProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self = self else { return }
                if progress != nil && self.viewState != .cleaning {
                    self.viewState = .cleaning
                }
            }
            .store(in: &cancellables)
        
        $cleanupResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in
                guard let self = self else { return }
                if !results.isEmpty {
                    self.viewState = .results
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - View State Management
    func resetCleanupState() {
        _cleanupViewModel = nil
        viewState = .scanning
    }
    
    func setViewState(_ newState: CleanerViewState) {
        viewState = newState
    }
    
    func startCleaning() {
        viewState = .cleaning
    }
    
    func showResults() {
        viewState = .results
    }
    
    func backToScanning() {
        viewState = .scanning
        cleanupResult = []
        scanResult = nil
        currentFiles = []
        currentCleaningProgress = nil
    }
    
    func scanCategories() async {
        await executeOperation(newState: .scanning(progress: nil)) {
            try await connectionService.ensureConnection()
            let result = try await scanService.performScan()
            await MainActor.run {
                self.scanResult = result
            }
            
        }
    }
    
    func loadFilesForCategory(_ category: CleanupCategory) async {
        await executeOperation(newState: .idle) {
            try await connectionService.ensureConnection()
            let files = try await scanService.getFilesForCategory(category)
            
           
            await MainActor.run {
                self.currentFiles = files
            }
        }
    }
    
    func cleanupCategories(
        _ categories: [CleanupCategory],
        options: CleanupOptions = .default,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        
        return try await executeAsyncOperation(newState: .cleaning(progress: nil)) {
            try await connectionService.ensureConnection()
            
            let results = try await cleanupService.performCleanup(
                categories: categories,
                options: options,
                progressHandler: { progress in
                    await MainActor.run {
                        self.currentCleaningProgress = progress
                    }
                    await progressHandler(progress)
                }
            )
            await MainActor.run {
                self.cleanupResult = results
            }
            
            return results
        }
    }
    
    func cleanupSpecificFiles(
        _ cleanupData: CleanupData,
        options: CleanupOptions = .default,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        
        return try await executeAsyncOperation(newState: .cleaning(progress: nil)) {
            try await connectionService.ensureConnection()
            
            let results = try await cleanupService.performSpecificFilesCleanup(
                cleanupData: cleanupData,
                options: options,
                progressHandler: { progress in
                    await MainActor.run {
                        self.currentCleaningProgress = progress
                    }
                    await progressHandler(progress)
                }
            )
            
            await MainActor.run {
                self.cleanupResult = results
            }
            return results
        }
    }
    
    func cancelCurrentOperation() async {
        guard isCleaning || isScanning else { return }
        
        await updateState(.cancelling)
        isCancelling = true
        
        await cleanupService.cancelCurrentOperation()
        
        await updateState(.cancelled)
        currentCleaningProgress = nil
        isCancelling = false
    }
    
    func ensureHelperInstalled() async {
        await executeOperation(newState: .connecting) {
            let _ = await helperService.ensureHelperIsRegistered()
        }
    }
    
    func reinstallHelper() async {
        await executeOperation(newState: .connecting) {
            await helperService.reinstallHelper()
            
            if await getHelperStatus() == .enabled {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await scanCategories()
            }
        }
    }
    
    func uninstallHelper() async throws {
        try await helperService.uninstallHelper()
        connectionService.invalidateConnection()
    }
    

    
    func getHelperStatus() async -> HelperStatusType {
       await helperService.updateStatus()
       return helperService.status
    }
    
    func tryRegisterHelper() async -> Bool {
        return await helperService.tryRegisterHelper()
    }
    
    func openSystemSettings() {
        helperService.openSystemSettings()
    }
    
    // MARK: - Private Helpers - Operation Management
    private func executeOperation<T>(
        newState: CleanerState,
        operation: () async throws -> T
    ) async {
        await updateState(newState)
        
        do {
            _ = try await operation()
            await updateState(.completed)
        } catch {
            await handleError(error)
        }
    }
    
    private func executeAsyncOperation<T>(
        newState: CleanerState,
        operation: () async throws -> T
    ) async throws -> T {
        await updateState(newState)
        
        do {
            let result = try await operation()
            await updateState(.completed)
            return result
        } catch {
            await handleError(error)
            throw error
        }
    }
    @MainActor
    private func updateState(_ newState: CleanerState) async {
        
        state = newState
    }
    
    private func handleError(_ error: Error) async {
        let errorMessage: String
        
        switch error {
        case let cleanerError as CleanerServiceError:
            errorMessage = cleanerError.localizedDescription
        default:
            errorMessage = error.localizedDescription
        }
        
        await updateState(.error(errorMessage))
    }
}


extension CleanerService {
    enum HelperStatusType: Equatable {
        case notRegistered     // rawValue: 0
        case enabled           // rawValue: 1
        case requiresApproval  // rawValue: 2
        case notFound          // rawValue: 3
        case unknown(Int)
        
        init(rawValue: Int) {
            switch rawValue {
            case 0: self = .notRegistered
            case 1: self = .enabled
            case 2: self = .requiresApproval
            case 3: self = .notFound
            default: self = .unknown(rawValue)
            }
        }
        
        var userMessage: String {
            switch self {
            case .enabled:
                return "Cleaning service is ready"
            case .requiresApproval:
                return "Please approve the cleaning service in System Settings > Privacy & Security > Login Items"
            case .notRegistered:
                return "Cleaning service needs to be registered"
            case .notFound:
                return "Cleaning service not found"
            case .unknown(let code):
                return "Unknown cleaning service status (\(code))"
            }
        }
        
        var shouldShowSystemSettings: Bool {
            self == .requiresApproval
        }
        
        var isError: Bool {
            self != .enabled
        }
        
        var needsUserAction: Bool {
            self == .requiresApproval
        }
        
        var canAutoRegister: Bool {
            self == .notRegistered
        }
    }
}
