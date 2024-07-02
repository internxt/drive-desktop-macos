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
    var backupRealm: BackupRealmProtocol!
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
        // Put teardown code here. This method is called after the invocation of each test method in the class.
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
    
    
    func testNodeSync() async throws {
        _ = try createFileInTmpDir("test1.txt")
        _ = try createDirectoryInTmpDir("folderA")
        _ = try createFileInTmpDir("folderA/test3.txt")
        let backupTree = try await sut.generateTree()
        try await backupTree.syncNode()
        
        XCTAssertEqual(backupTree.syncStatus, .REMOTE_AND_LOCAL )
    }
    
    
    func testNodeSyncOperationQueue() async throws {
        _ = try createFileInTmpDir("test1.txt")
        _ = try createDirectoryInTmpDir("folderA")
        _ = try createFileInTmpDir("folderA/test3.txt")
        let backupTree = try await sut.generateTree()
        XCTAssertNoThrow(try backupTree.syncBelowNodes(withOperationQueue: uploadOperationQueue))
    }
    
    func testNodeSyncRetries() async throws {
        let backupTree = try await sut.generateTree()
        mockBackupUploadService.syncResult = .failure(BackupUploadError.CannotCreateEncryptedContentURL)
        try await backupTree.syncNode()
        XCTAssertEqual(backupTree.syncRetries, 3 )
    }
    
    func testNodeUrlIsMissing() async throws {
        let backupTree = try await sut.generateTree()
        backupTree.url = nil
        let expectation = self.expectation(description: "syncNode() should throw")
        
        Task {
            do {
                try await backupTree.syncNode()
                XCTFail("syncNode() should throw an error")
            } catch {
                XCTAssertEqual(error as? BackupTreeNodeError, .cannotGetPath)
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5)
    }
    
    func testNodeisAlreadySync() async throws {
        
        let backupTree = try await sut.generateTree()
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
        XCTAssertEqual(backupTree.syncStatus, .REMOTE_AND_LOCAL )
    }
    
    func testGenerateTreeFromUrlsTest() async throws {
        let fileTest1 = try createFileInTmpDir("test1.txt")
        let folderA = try createDirectoryInTmpDir("folderA")
        let fileTest2 = try createFileInTmpDir("folderA/test3.txt")
        
        let backupTree = try await sut.generateTree()
        
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
        XCTAssertEqual(fileTest3ParentNode!.url, folderA )
    }
    
    func testStructureIsCorrect() async throws {
        let fileURL = try createFileInTmpDir("FolderA/FolderB/FolderC/FolderD/FolderE/file.txt")
        
        let backupTree = try await sut.generateTree()
        
        let fileNode = backupTree.findNode(fileURL)
        
        
        // Node exists
        XCTAssertEqual(fileNode!.url, fileURL )
        let firstParent = backupTree.findNodeById(fileNode!.parentId!)
        
        XCTAssertEqual(firstParent?.name, "FolderE")
        
        let secondParent = backupTree.findNodeById(firstParent!.parentId!)
        
        XCTAssertEqual(secondParent?.name, "FolderD")
        
        let thirdParent = backupTree.findNodeById(secondParent!.parentId!)
        
        XCTAssertEqual(thirdParent?.name, "FolderC")
        
        let fourthParent = backupTree.findNodeById(thirdParent!.parentId!)
        
        XCTAssertEqual(fourthParent?.name, "FolderB")
        
    }
}
