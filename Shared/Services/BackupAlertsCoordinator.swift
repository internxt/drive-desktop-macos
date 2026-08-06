//
//  BackupAlertsCoordinator.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 15/6/26.
//

import AppKit
import Foundation

final class BackupAlertsCoordinator {
    private let fileSizeLimitState: FileSizeLimitState
    private let emptyFileLimitState: EmptyFileLimitState
    private let storageFullState: StorageFullState
    private let windowsManager: WindowsManager

    private let debounceInterval: TimeInterval = 0.6

    // File Size Limit State
    private var fileSizePendingAlert: DispatchWorkItem?
    private var fileSizeAlertIsShowing = false

    // Empty File Limit State
    private var emptyFilePendingAlert: DispatchWorkItem?
    private var emptyFileAlertIsShowing = false

    init(fileSizeLimitState: FileSizeLimitState, emptyFileLimitState: EmptyFileLimitState, storageFullState: StorageFullState, windowsManager: WindowsManager) {
        self.fileSizeLimitState = fileSizeLimitState
        self.emptyFileLimitState = emptyFileLimitState
        self.storageFullState = storageFullState
        self.windowsManager = windowsManager
    }

  

    public func handleFileSizeExceeded(_ notification: Notification) {
        fileSizePendingAlert?.cancel()

        guard !fileSizeAlertIsShowing else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.presentFileSizeAlert()
        }
        fileSizePendingAlert = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + debounceInterval,
            execute: work
        )
    }

    private func presentFileSizeAlert() {
        let batch = FileSizeLimitNotifier.readAndResetBatch()
        fileSizeLimitState.isBatch    = batch.rejectedCount > 1
        fileSizeLimitState.filename   = batch.filename
        fileSizeLimitState.fileSize   = batch.fileBytes
        fileSizeLimitState.limitBytes = batch.limitBytes
        fileSizeLimitState.isVisible  = true

        windowsManager.openWindow(id: "file-size-limit")
        fileSizeAlertIsShowing = false
    }

 

    public func handleEmptyFileLimitReached() {
        emptyFilePendingAlert?.cancel()

        guard !emptyFileAlertIsShowing else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.presentEmptyFileLimitAlert()
        }
        emptyFilePendingAlert = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + debounceInterval,
            execute: work
        )
    }

    private func presentEmptyFileLimitAlert() {
        let batch = EmptyFileLimitNotifier.readAndResetBatch()
        emptyFileLimitState.isBatch        = batch.rejectedCount > 1
        emptyFileLimitState.firstFilename  = batch.firstFilename
        emptyFileLimitState.rejectedCount  = batch.rejectedCount
        emptyFileLimitState.reason         = batch.reason
        emptyFileLimitState.isVisible      = true

        windowsManager.openWindow(id: "empty-file-limit")
        emptyFileAlertIsShowing = false
    }

    public func handleStorageFullReached() {
        guard !storageFullState.isVisible else { return }
        storageFullState.isVisible = true
        windowsManager.openWindow(id: "storage-full")
    }
}
