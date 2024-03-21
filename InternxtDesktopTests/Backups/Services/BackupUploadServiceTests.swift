//
//  BackupUploadServiceTests.swift
//  InternxtDesktopTests
//
//  Created by Richard Ascanio on 3/19/24.
//

import XCTest
import InternxtSwiftCore
import RealmSwift

final class BackupUploadServiceTests: XCTestCase {
    var backupUploadService: BackupUploadService!
    var backupClient: MockBackupClient!
    var tmpDirectoryURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        Realm.Configuration.defaultConfiguration.inMemoryIdentifier = "test"

        tmpDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BACKUP_TREE_GENERATOR_TESTS_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDirectoryURL, withIntermediateDirectories: true)
        backupClient = MockBackupClient()
        let networkAPI = NetworkAPI(baseUrl: "", basicAuthToken: "", clientName: "", clientVersion: "")
        backupUploadService = BackupUploadService(
            networkFacade: NetworkFacade(mnemonic: "", networkAPI: networkAPI),
            encryptedContentDirectory: URL(fileURLWithPath: "file:///Users/Desktop"),
            deviceId: 1090,
            bucketId: "bucket-id",
            authToken: "auth-token",
            newAuthToken: "auth-legacy-token",
            backupClient: backupClient
        )
    }

    override func tearDownWithError() throws {
        backupUploadService = nil
        backupClient = nil
        try FileManager.default.removeItem(at: tmpDirectoryURL)

        try super.tearDownWithError()
    }

    private func createFileInTmpDir(_ fileRelativePath: String) throws -> URL {
        let url = tmpDirectoryURL.appendingPathComponent(fileRelativePath)

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        FileManager.default.createFile(atPath: url.path(), contents: nil)

        return url
    }

    private func createDirectoryInTmpDir(_ directoryRelativePath: String) throws -> URL {
        let url = tmpDirectoryURL.appendingPathComponent(directoryRelativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }

    func testFolderUploadWhenNodeURLIsNilReturnError() {
        // Arrange
        let node = BackupTreeNode(
            id: "node-id",
            parentId: nil,
            name: "New Folder",
            type: .folder,
            url: nil,
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: [],
            backupUploadService: backupUploadService,
            progress: Progress()
        )

        // Act
        Task {
            let result = await self.backupUploadService.doSync(node: node)

            switch result {
            case .failure(let error):
                // Assert
                XCTAssertNotNil(error, "Sync method did not return the expected error")
                break
            default:
                XCTAssertFalse(true, "Test failed")
                break
            }

        }
    }

    func testFolderUploadWhenAPIErrorWithParentIdReturnError() {
        // Arrange
        let node = BackupTreeNode(
            id: "node-id",
            parentId: "563",
            name: "New Folder",
            type: .folder,
            url: URL(fileURLWithPath: "file:///Users/Desktop"),
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: [],
            backupUploadService: backupUploadService,
            progress: Progress()
        )

        backupClient.shouldReturnError = true

        // Act
        Task {
            let result = await self.backupUploadService.doSync(node: node)

            switch result {
            case .failure(let error):
                // Assert
                XCTAssertNotNil(error, "Sync method did not return the expected error")
                break
            default:
                XCTAssertFalse(true, "Test failed")
                break
            }

        }
    }

    func testFolderUploadWhenAPIErrorReturnError() {
        // Arrange
        let node = BackupTreeNode(
            id: "node-id",
            parentId: nil,
            name: "New Folder",
            type: .folder,
            url: URL(fileURLWithPath: "file:///Users/Desktop"),
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: [],
            backupUploadService: backupUploadService,
            progress: Progress()
        )

        backupClient.shouldReturnError = true

        // Act
        Task {
            let result = await self.backupUploadService.doSync(node: node)

            switch result {
            case .failure(let error):
                // Assert
                XCTAssertNotNil(error, "Sync method did not return the expected error")
                break
            default:
                XCTAssertFalse(true, "Test failed")
                break
            }

        }
    }

    func testFolderUploadWhenAPISuccessReturnSuccess() {
        // Arrange
        let node = BackupTreeNode(
            id: "node-id",
            parentId: nil,
            name: "New Folder",
            type: .folder,
            url: URL(fileURLWithPath: "file:///Users/user/Desktop"),
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: [],
            backupUploadService: backupUploadService,
            progress: Progress()
        )

        backupClient.shouldReturnError = false

        // Act
        Task {
            let result = await self.backupUploadService.doSync(node: node)

            switch result {
            case .success(let createdFolder):
                // Assert
                XCTAssertNotNil(createdFolder)
                break
            default:
                XCTAssertFalse(true, "Test failed")
                break
            }
        }
    }

    func testFileUploadWithoutParentIdReturnError() throws {
        // Arrange
        let fileTest = try createFileInTmpDir("folderA/test3.txt")
        let node = BackupTreeNode(
            id: "node-id",
            parentId: nil,
            name: "test3",
            type: .text,
            url: fileTest,
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: [],
            backupUploadService: backupUploadService,
            progress: Progress()
        )

        // Act
        Task {
            let result = await self.backupUploadService.doSync(node: node)

            switch result {
            case .failure(let error):
                // Assert
                XCTAssertNotNil(error, "Sync method did not return the expected error")
                break
            default:
                XCTAssertFalse(true, "Test failed")
                break
            }

        }
    }

    func testFileUploadReturnSuccess() throws {
        // Arrange
        let fileTest = try createFileInTmpDir("folderA/test3.txt")
        let node = BackupTreeNode(
            id: "test3",
            parentId: "qwuy21637dwe",
            name: "notes",
            type: .text,
            url: fileTest,
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: [],
            backupUploadService: backupUploadService,
            progress: Progress()
        )

        node.remoteParentId = 234873

        // Act
        Task {
            let result = await self.backupUploadService.doSync(node: node)

            switch result {
            case .success(let success):
                // Assert
                XCTAssertNotNil(success, "Sync method did not return the expected response")
                break
            default:
                XCTAssertFalse(true, "Test failed")
                break
            }

        }
    }

    func testFileUploadUpdateReturnSuccess() throws {
        // Arrange
        let fileTest = try createFileInTmpDir("folderA/test3.txt")

        let node = BackupTreeNode(
            id: "node-id",
            parentId: "qwuy21637dw332e",
            name: "test3",
            type: .text,
            url: fileTest,
            syncStatus: BackupTreeNodeSyncStatus.NEEDS_UPDATE,
            childs: [],
            backupUploadService: backupUploadService,
            progress: Progress()
        )

        node.remoteParentId = 34432

        // Act
        Task {
            let result = await self.backupUploadService.doSync(node: node)

            switch result {
            case .success(let success):
                // Assert
                XCTAssertNotNil(success, "Sync method did not return the expected response")
                break
            default:
                XCTAssertFalse(true, "Test failed")
                break
            }

        }
    }

}
