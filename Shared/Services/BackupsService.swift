//
//  BackupsService.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/8/24.
//

import Foundation
import RealmSwift
import InternxtSwiftCore

enum BackupError: Error {
    case cannotCreateURL
    case cannotAddFolder
    case cannotDeleteFolder
    case cannotFindFolder
    case emptyFolders
}

class BackupsService: ObservableObject {
    @Published var deviceResponse: Result<[Device], Error>? = nil
    @Published var foldernames: [FoldernameToBackup] = []

    private func getRealm() -> Realm {
        do {
            return try Realm(fileURL: ConfigLoader.realmURL)
        } catch {
            error.reportToSentry()
            fatalError("Unable to open Realm")
        }

    }

    func clean() throws {
        foldernames = []
        let realm = getRealm()
        try realm.write {
            realm.deleteAll()
        }
    }

    func addFoldernameToBackup(_ foldernameToBackup: FoldernameToBackup) throws {
        guard let _ = URL(string: foldernameToBackup.url) else {
            throw BackupError.cannotCreateURL
        }

        do {
            let realm = getRealm()
            try realm.write {
                realm.add(foldernameToBackup)
            }
            self.foldernames.append(foldernameToBackup)
        } catch {
            error.reportToSentry()
            throw BackupError.cannotAddFolder
        }
    }

    func removeFoldernameFromBackup(id: String) throws {
        let itemToDelete = foldernames.first { foldername in
            return foldername.id == id
        }
        guard let itemToDelete = itemToDelete else {
            throw BackupError.cannotFindFolder
        }

        do {
            let realm = getRealm()
            try realm.write {
                realm.delete(itemToDelete)
            }
            self.assignUrls()
        } catch {
            error.reportToSentry()
            throw BackupError.cannotDeleteFolder
        }
    }

    func getFoldernames() -> [String] {
        let foldernamesToBackup = getRealm().objects(FoldernameToBackup.self).sorted(byKeyPath: "createdAt", ascending: false)

        var array: [String] = []
        for foldername in foldernamesToBackup {
            if let url = URL(string: foldername.url) {
                array.append(url.lastPathComponent)
            }
        }

        return array
    }

    func assignUrls() {
        let foldernamesToBackup = getRealm().objects(FoldernameToBackup.self).sorted(byKeyPath: "createdAt", ascending: true)

        var folders: [FoldernameToBackup] = []
        for foldername in foldernamesToBackup {
            if let _ = URL(string: foldername.url) {
                folders.append(foldername)
            }
        }
        self.foldernames = folders
    }

    func loadAllDevices() async {
        do {
            self.deviceResponse = .success(try await DeviceService.shared.getAllDevices(deviceName: ConfigLoader().getDeviceName()))
        } catch {
            error.reportToSentry()
            self.deviceResponse = .failure(error)
        }
    }

    func addCurrentDevice() async {
        do {
            if let currentDeviceName = ConfigLoader().getDeviceName() {
                try await DeviceService.shared.addCurrentDevice(deviceName: currentDeviceName)
            }
        } catch {
            error.reportToSentry()
        }
    }

    func syncBackup() async throws {
        if foldernames.isEmpty {
            throw BackupError.emptyFolders
        }

        //TODO: add for each statement and do this process for all items on foldernames array
        guard let foldernameURL = URL(string: foldernames[0].url) else {
            throw BackupError.cannotCreateURL
        }

        let treeGenerator = BackupTreeGenerator(root: foldernameURL)
        try await treeGenerator.rootNode.syncNodes()
    }
}

class FoldernameToBackup: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var url: String
    @Persisted var status: FoldernameToBackupStatus
    @Persisted var createdAt: Date

    convenience init(
        url: String,
        status: FoldernameToBackupStatus
    ) {
        self.init()
        self.url = url
        self.createdAt = Date()
        self.status = status
    }
}

extension FoldernameToBackup: Identifiable {
    var id: String {
        return _id.stringValue
    }
}

enum FoldernameToBackupStatus: String, PersistableEnum {
    case hasIssues
    case selected
    case inProgress
}
