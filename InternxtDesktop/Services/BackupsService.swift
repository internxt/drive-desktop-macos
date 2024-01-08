//
//  BackupsService.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/8/24.
//

import Foundation
import RealmSwift

class BackupsService: ObservableObject {
    @Published var foldernames: [FoldernameToBackup] = []
    @Published var urls: [URL] = []
    @Published var isBackupButtonEnabled: Bool = false

    private func getRealm() -> Realm {
        do {
            return try Realm(fileURL: ActivityManager.realmURL)
        } catch {
            error.reportToSentry()
            fatalError("Unable to open Realm")
        }

    }

    func clean() throws {
        foldernames = []
        urls = []
        let realm = getRealm()
        try realm.write {
            realm.deleteAll()
        }
    }

    func addFoldernameToBackup(_ foldernameToBackup: FoldernameToBackup) {
        guard let url = URL(string: foldernameToBackup.url) else {
            return
        }

        do {
            let realm = getRealm()
            try realm.write {
                realm.add(foldernameToBackup)
            }
            self.urls.append(url)
        } catch {
            error.reportToSentry()
        }
    }

    func removeFoldernameFromBackup(at index: Int) {
        let array = getRealm().objects(FoldernameToBackup.self).sorted(byKeyPath: "createdAt", ascending: false)

        let itemToDelete = array[index]
        do {
            let realm = getRealm()
            try realm.write {
                realm.delete(itemToDelete)
            }
            self.urls.remove(at: index)
        } catch {
            error.reportToSentry()
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
        let foldernamesToBackup = getRealm().objects(FoldernameToBackup.self).sorted(byKeyPath: "createdAt", ascending: false)

        var array: [URL] = []
        for foldername in foldernamesToBackup {
            if let url = URL(string: foldername.url) {
                array.append(url)
            }
        }
        self.isBackupButtonEnabled = !array.isEmpty
        self.urls = array
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

enum FoldernameToBackupStatus: String, PersistableEnum {
    case hasIssues
    case selected
    case inProgress
}
