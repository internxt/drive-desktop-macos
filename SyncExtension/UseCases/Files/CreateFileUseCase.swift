//
//  CreateFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 10/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log

enum CreateFileUseCaseError: Error {
    case InvalidParentId
    case CannotOpenInputStream
    case MissingDocumentSize
}


struct CreateFileUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "CreateFile")
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let item: NSFileProviderItem
    private let encryptedFileDestination: URL
    private let fileContent: URL
    private let networkFacade: NetworkFacade
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let driveAPI = APIFactory.Drive
    private let config = ConfigLoader().get()
    init(item: NSFileProviderItem, url: URL, encryptedFileDestination: URL, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.item = item
        
        self.fileContent = url
        self.encryptedFileDestination = encryptedFileDestination
        self.completionHandler = completionHandler
        self.networkFacade = NetworkFacade(mnemonic: config.MNEMONIC, networkAPI: APIFactory.Network)
    }
 
    public func run() -> Progress {
        self.logger.info("Creating file")
        let progress = Progress(totalUnitCount: 100)
        
        Task {
            do {
               
                guard let inputStream = InputStream(url: fileContent) else {
                    throw CreateFileUseCaseError.CannotOpenInputStream
                }
                
                guard let size = item.documentSize else {
                    throw CreateFileUseCaseError.MissingDocumentSize
                }
                
                guard let sizeInt = size?.intValue else {
                    throw CreateFileUseCaseError.MissingDocumentSize
                }
                
                
                let filename = (item.filename as NSString)
                self.logger.info("Starting upload for file \(filename)")
                self.logger.info("Parent id: \(item.parentItemIdentifier.rawValue)")
                
               
                /// Upload a file to the Internxt network and returns an id used later to create a file in Drive with that fileId
                let result = try await networkFacade.uploadFile(
                    input: inputStream,
                    encryptedOutput: encryptedFileDestination,
                    fileSize: sizeInt,
                    bucketId: ConfigLoader().get().BUCKET_ID,
                    progressHandler:{ completedProgress in
                        progress.completedUnitCount = Int64(completedProgress * 100)
                    }
                )
                
                self.logger.info("Upload completed with id \(result.id)")
                let parentId = item.parentItemIdentifier == .rootContainer ? config.ROOT_FOLDER_ID : item.parentItemIdentifier.rawValue
                guard let folderIdInt = Int(item.parentItemIdentifier == .rootContainer ? config.ROOT_FOLDER_ID : item.parentItemIdentifier.rawValue) else {
                    throw CreateFileUseCaseError.InvalidParentId
                }
                
                let encryptedFilename = try encrypt.encrypt(
                    string: filename.deletingPathExtension,
                    password: "\(config.CRYPTO_SECRET2)-\(item.parentItemIdentifier.rawValue)",
                    salt: cryptoUtils.hexStringToBytes(config.MAGIC_SALT_HEX),
                    iv: Data(cryptoUtils.hexStringToBytes(config.MAGIC_IV_HEX))
                )
                
                let createdFile = try await driveAPI.createFile(createFile: CreateFileData(
                    fileId: result.id,
                    type: filename.pathExtension,
                    bucket: result.bucket,
                    size: result.size,
                    folderId: folderIdInt,
                    name: encryptedFilename.base64EncodedString(),
                    plainName: filename.deletingPathExtension
                ))
                
                completionHandler(FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(createdFile.id)), filename: item.filename, parentId: NSFileProviderItemIdentifier(rawValue: parentId), createdAt: Time.dateFromISOString(createdFile.createdAt) ?? Date(), updatedAt: Time.dateFromISOString(createdFile.updatedAt) ?? Date(), itemExtension: createdFile.type, itemType: .file), [], false, nil )
                
            } catch {
                print(error)
                self.logger.error("Failed to create file: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return progress
    }
}
