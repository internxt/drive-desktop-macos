//
//  BackupUploadServiceTests.swift
//  XPCBackupServiceTests
//
//  Created by Patricio Tovar on 27/7/26.
//

import Foundation
import Testing
import InternxtSwiftCore

// MARK: - Tags

extension Tag {
    @Tag static var backupLifecycle: Self
    @Tag static var concurrency: Self
}

// MARK: - BackupUploadServiceTests

struct BackupUploadServiceTests {

    // MARK: - Properties

    let tmpDirectoryURL: URL
    let backupRealm: MockBackupRealm
    let mockUploadService: MockBackupUploadService

    // MARK: - Init

    init() throws {
        let tempURL = URL(fileURLWithPath: "/private\(NSTemporaryDirectory())")
            .appendingPathComponent("BACKUP_UPLOAD_SERVICE_TESTS_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)

        self.tmpDirectoryURL = tempURL
        self.backupRealm = MockBackupRealm()
        self.mockUploadService = MockBackupUploadService()
    }

    // MARK: - Private Helpers

    private func createFile(_ relativePath: String) throws -> URL {
        let url = tmpDirectoryURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let created = FileManager.default.createFile(atPath: url.path(), contents: "test".data(using: .utf8))
        try #require(created, "Failed to create test file at \(url.path())")
        return url
    }

    private func makeTree(progress: Progress = Progress()) async throws -> BackupTreeNode {
        let generator = BackupTreeGenerator(
            root: tmpDirectoryURL,
            deviceId: 999,
            backupUploadService: mockUploadService,
            backupTotalProgress: progress,
            backupRealm: backupRealm
        )
        let (tree, _) = try await generator.generateTree()
        return tree
    }

   
    private func wait(for group: DispatchGroup) async {
        await withCheckedContinuation { continuation in
            group.notify(queue: .global()) { continuation.resume() }
        }
    }

   

    @Test("stopSync() immediately stops uploads and removes child nodes", .tags(.backupLifecycle), .bug(id: "BR-2119"))
    func stopSyncPreventsSubsequentUploadsAndCleansTree() async throws {
        defer { try? FileManager.default.removeItem(at: tmpDirectoryURL) }

        _ = try createFile("folder/file1.txt")
        let tree = try await makeTree()

        try #require(mockUploadService.canDoBackup == true, "canDoBackup must be true before stopSync()")
        try #require(!tree.childs.isEmpty, "Generated tree must have children for this test to be meaningful")

        mockUploadService.stopSync()

      
        #expect(mockUploadService.canDoBackup == false, "stopSync() must set canDoBackup = false synchronously")


        let result = await mockUploadService.doSync(node: tree)
        do {
            _ = try result.get()
            Issue.record("doSync must not succeed when canDoBackup is false")
        } catch let error as BackupUploadError {
            #expect(error == .BackupStoppedManually, "Expected .BackupStoppedManually, got: \(error)")
        } catch {
            Issue.record("Unexpected error type thrown: \(error)")
        }

      
        #expect(tree.childs.isEmpty, "doSync must remove child nodes when canDoBackup is false")
    }



    @Test("After stop-and-restart, progress advances and uploads are attempted",
          .tags(.backupLifecycle, .concurrency), .bug(id: "BR-2119"), .timeLimit(.minutes(1)))
    func progressAndUploadsOccurAfterRestart() async throws {
        defer { try? FileManager.default.removeItem(at: tmpDirectoryURL) }

        _ = try createFile("doc1.txt")
        _ = try createFile("doc2.txt")

        let progressSession1 = Progress(totalUnitCount: 10)
        let treeSession1 = try await makeTree(progress: progressSession1)
        mockUploadService.stopSync()
        try await treeSession1.syncNode()

        mockUploadService.reset()
        try #require(mockUploadService.canDoBackup == true, "reset() must restore canDoBackup to true")

        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 5

        let progressSession2 = Progress(totalUnitCount: 10)
        let treeSession2 = try await makeTree(progress: progressSession2)

        let syncGroup = DispatchGroup()
        try treeSession2.syncBelowNodes(
            withOperationQueue: operationQueue,
            syncGroup: syncGroup,
            onError: { _ in }
        )
        await wait(for: syncGroup)

        // UI must not be stuck at 0%
        #expect(progressSession2.completedUnitCount > 0,
            "completedUnitCount must be > 0 after restart — the UI must not be stuck at 0%")

        #expect(mockUploadService.doSyncCallCount > 0,
            "doSync must be called in the new session — files must be attempted for upload")
    }


    @Test("New session OperationQueue processes files independently",
          .tags(.backupLifecycle, .concurrency), .bug(id: "BR-2119"), .timeLimit(.minutes(1)))
    func newSessionOperationQueueIsClean() async throws {
        defer { try? FileManager.default.removeItem(at: tmpDirectoryURL) }

        _ = try createFile("image.png")

        let queueSession1 = OperationQueue()
        queueSession1.maxConcurrentOperationCount = 5

        let tree1 = try await makeTree()
        let syncGroup1 = DispatchGroup()
        try tree1.syncBelowNodes(
            withOperationQueue: queueSession1,
            syncGroup: syncGroup1,
            onError: { _ in }
        )
        queueSession1.cancelAllOperations()
        await wait(for: syncGroup1)

        try #require(queueSession1.operationCount == 0,
            "Session 1's queue must be empty after cancelAllOperations + drain")

        mockUploadService.reset()
        try #require(mockUploadService.canDoBackup == true, "reset() must restore canDoBackup to true")
        let callCountBeforeSession2 = mockUploadService.doSyncCallCount

        let queueSession2 = OperationQueue()
        queueSession2.maxConcurrentOperationCount = 5

        let tree2 = try await makeTree()
        let syncGroup2 = DispatchGroup()
        try tree2.syncBelowNodes(
            withOperationQueue: queueSession2,
            syncGroup: syncGroup2,
            onError: { _ in }
        )
        await wait(for: syncGroup2)

        #expect(mockUploadService.doSyncCallCount > callCountBeforeSession2,
            "Session 2 must call doSync independently — no interference from session 1's canceled queue")
    }
}
