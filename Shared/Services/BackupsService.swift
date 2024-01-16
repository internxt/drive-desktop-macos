//
//  BackupsService.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/8/24.
//

import Foundation
import RealmSwift

enum BackupError: Error {
    case cannotCreateURL
    case cannotAddFolder
    case cannotDeleteFolder
    case cannotFindFolder
}

class BackupsService: ObservableObject {
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
