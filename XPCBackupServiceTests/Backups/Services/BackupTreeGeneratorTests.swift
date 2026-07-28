//
//  BackupTreeGeneratorTests.swift
//  InternxtDesktopTests
//
//  Created by Robert Garcia on 9/2/24.
//

import XCTest
import InternxtSwiftCore

final class BackupTreeGeneratorTests: XCTestCase {
    var sut: BackupTreeGenerator!
    var tmpDirectoryURL: URL!
    var backupRealm: any SyncedNodeRepositoryProtocol = MockBackupRealm()
    var mockBackupUploadService: MockBackupUploadService!
    private var uploadOperationQueue = OperationQueue()
    
    override func setUpWithError() throws {
        tmpDirectoryURL = URL(fileURLWithPath: "/private\(NSTemporaryDirectory())").appendingPathComponent("BACKUP_TREE_GENERATOR_TESTS_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDirectoryURL, withIntermediateDirectories: true)
        
        backupRealm = MockBackupRealm()
        mockBackupUploadService = MockBackupUploadService()
        sut = BackupTreeGenerator(
            root: tmpDirectoryURL,
            deviceId: 999,
            backupUploadService: mockBackupUploadService,
            backupTotalProgress: Progress(), backupRealm: backupRealm
        )
    }
    
    override func tearDownWithError() throws {
        if let url = tmpDirectoryURL {
            try? FileManager.default.removeItem(at: url)
        }
        sut = nil
        mockBackupUploadService = nil
        tmpDirectoryURL = nil
    }
    
    private func createFileInTmpDir(_ fileRelativePath: String) throws -> URL {
        let url = tmpDirectoryURL.appendingPathComponent(fileRelativePath)
        
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let created = FileManager.default.createFile(atPath: url.path(), contents: "test".data(using: .utf8))
        if !created {
            throw XCTSkip("Could not create test file at \(url.path())")
        }
        
        return url
    }
    
    private func createDirectoryInTmpDir(_ directoryRelativePath: String) throws -> URL {
        let url = tmpDirectoryURL.appendingPathComponent(directoryRelativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        
        return url
    }
    
    func testNodeSync() async throws {
        let fileTest1 = try createFileInTmpDir("test1.txt")
        _ = try createDirectoryInTmpDir("folderA")
        _ = try createFileInTmpDir("folderA/test3.txt")
        let (backupTree, _) = try await sut.generateTree()
        try await backupTree.syncNode()
        
        XCTAssertEqual(backupTree.syncStatus, .REMOTE_AND_LOCAL)
        let childNode = backupTree.findNode(fileTest1)
        XCTAssertNotNil(childNode)
    }
    
    func testNodeSyncOperationQueue() async throws {
        _ = try createFileInTmpDir("test1.txt")
        _ = try createDirectoryInTmpDir("folderA")
        _ = try createFileInTmpDir("folderA/test3.txt")
        let (backupTree, _) = try await sut.generateTree()
        let syncGroup = DispatchGroup()
        XCTAssertNoThrow(try backupTree.syncBelowNodes(withOperationQueue: uploadOperationQueue, syncGroup: syncGroup, onError: { _ in }))
        
        let expectation = expectation(description: "syncGroup drains")
        syncGroup.notify(queue: .global()) { expectation.fulfill() }
        await fulfillment(of: [expectation], timeout: 10)
        
        XCTAssertGreaterThan(mockBackupUploadService.doSyncCallCount, 0, "At least one node should be processed")
    }
    
    func testNodeSyncRetries() async throws {
        let (backupTree, _) = try await sut.generateTree()
        let retryableError = NSError(domain: "NetworkError", code: 500, userInfo: nil)
        mockBackupUploadService.syncResult = .failure(retryableError)
        
        do {
            try await backupTree.syncNode()
            XCTFail("syncNode() should throw after exhausting all retries")
        } catch {
            XCTAssertEqual(backupTree.syncRetries, 3)
        }
    }
    
    func testNodeUrlIsMissing() async throws {
        let (backupTree, _) = try await sut.generateTree()
        backupTree.url = nil
        
        do {
            try await backupTree.syncNode()
            XCTFail("syncNode() should throw an error when url is nil")
        } catch {
            XCTAssertEqual(error as? BackupTreeNodeError, .cannotGetPath)
        }
    }
    
    func testNodeisAlreadySync() async throws {
        let (backupTree, _) = try await sut.generateTree()
        let node = SyncedNode(
            remoteId: 2,
            deviceId: 999,
            remoteUuid: "",
            url: tmpDirectoryURL,
            rootBackupFolder: tmpDirectoryURL,
            parentId: "22",
            remoteParentId: 10
        )
        
        try backupRealm.addSyncedNode(node)
        try await backupTree.syncNode()
        XCTAssertEqual(backupTree.syncStatus, .REMOTE_AND_LOCAL)
    }
    
    func testGenerateTreeFromUrlsTest() async throws {
        let fileTest1 = try createFileInTmpDir("test1.txt")
        let folderA = try createDirectoryInTmpDir("folderA")
        let fileTest2 = try createFileInTmpDir("folderA/test3.txt")
        
        let (backupTree, _) = try await sut.generateTree()
        
        // Ensure the root is the backup root
        XCTAssertEqual(backupTree.url, tmpDirectoryURL)
        
        let fileTest1Node = backupTree.findNode(fileTest1)
        let fileTest1AsChild = backupTree.childs.first(where: {
            return $0.id == fileTest1Node!.id
        })
        // Ensure that test1.txt is a direct child node of the backup root
        XCTAssertNotNil(fileTest1AsChild)
        
        // Find the fileTest2 node
        let fileTest2Node = backupTree.findNode(fileTest2)
        
        // Ensure that folderA/ is the parent node of folderA/test2.txt
        let fileTest3ParentNode = backupTree.findNodeById(fileTest2Node!.parentId!)
        XCTAssertEqual(fileTest3ParentNode!.url, folderA)
    }
    
    func testStructureIsCorrect() async throws {
        let fileURL = try createFileInTmpDir("FolderA/FolderB/FolderC/FolderD/FolderE/file.txt")
        
        let (backupTree, _) = try await sut.generateTree()
        
        let fileNode = try XCTUnwrap(backupTree.findNode(fileURL), "fileNode should exist in generated tree")
        XCTAssertEqual(fileNode.url, fileURL)
        
        let firstParentId = try XCTUnwrap(fileNode.parentId, "firstParentId should not be nil")
        let firstParent = try XCTUnwrap(backupTree.findNodeById(firstParentId), "FolderE should exist")
        XCTAssertEqual(firstParent.name, "FolderE")
        
        let secondParentId = try XCTUnwrap(firstParent.parentId, "secondParentId should not be nil")
        let secondParent = try XCTUnwrap(backupTree.findNodeById(secondParentId), "FolderD should exist")
        XCTAssertEqual(secondParent.name, "FolderD")
        
        let thirdParentId = try XCTUnwrap(secondParent.parentId, "thirdParentId should not be nil")
        let thirdParent = try XCTUnwrap(backupTree.findNodeById(thirdParentId), "FolderC should exist")
        XCTAssertEqual(thirdParent.name, "FolderC")
        
        let fourthParentId = try XCTUnwrap(thirdParent.parentId, "fourthParentId should not be nil")
        let fourthParent = try XCTUnwrap(backupTree.findNodeById(fourthParentId), "FolderB should exist")
        XCTAssertEqual(fourthParent.name, "FolderB")
    }
}
