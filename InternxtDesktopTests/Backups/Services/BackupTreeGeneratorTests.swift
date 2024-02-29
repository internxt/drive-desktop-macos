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
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        tmpDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BACKUP_TREE_GENERATOR_TESTS_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDirectoryURL, withIntermediateDirectories: true)
        let networkAPI = NetworkAPI(baseUrl: "", basicAuthToken: "", clientName: "", clientVersion: "")
        sut = BackupTreeGenerator(root: tmpDirectoryURL, backupUploadService: BackupUploadService(networkFacade: NetworkFacade(mnemonic: "", networkAPI: networkAPI), encryptedContentDirectory: URL(string: "https://drive.internxt.com/app")!, deviceId: 0, bucketId: "", authToken: ""), progress: Progress())
    }
    
    override func tearDownWithError() throws {
        // Remove the temporary directory after the test
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
    
    
    func testGenerateTreeFromUrls() async throws {
        
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
