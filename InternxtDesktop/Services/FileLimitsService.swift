//
//  FileLimitsService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 11/5/26.
//

import Foundation
import InternxtSwiftCore
import Combine

class FileLimitsService: ObservableObject {

    static let shared = FileLimitsService()

    private let config   = ConfigLoader()
    private let logger   = LogService.shared.createLogger(
        subsystem: .InternxtDesktop, category: "FileLimitsService")


    @Published private(set) var maxUploadFileSizeBytes: Int64 = Int64.max

    // MARK: Private

    private var refreshTimer: AnyCancellable?
    private let refreshInterval: TimeInterval = 5 * 60   // 5 minutes

    private init() {
        maxUploadFileSizeBytes = config.getMaxFileSizeBytes()
    }


    func startPolling() {
        Task { await fetchIfNeeded() }

        refreshTimer = Timer
            .publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetchIfNeeded() }
            }
    }

 
    func stopPolling() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

 
    func clearCache() {
        config.clearMaxFileSize()
        maxUploadFileSizeBytes = Int64.max
    }

 

    @MainActor
    private func fetchIfNeeded() async {
        guard config.fileSizeLimitNeedsRefresh() else {
           
            return
        }
        await fetchLimits()
    }

    @MainActor
    private func fetchLimits() async {
        do {
           
            let response = try await APIFactory.DriveNew.getFileLimits()
            let rawBytes = Int64(response.maxUploadFileSize ?? 0)
            config.setMaxFileSizeBytes(rawBytes)
            maxUploadFileSizeBytes = config.getMaxFileSizeBytes()
          
        } catch {
      
            logger.error("❌ Failed to fetch file limits: \(error.localizedDescription)")
        }
    }
}
