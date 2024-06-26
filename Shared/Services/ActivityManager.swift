//
//  ActivityManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/9/23.
//

import Foundation
import RealmSwift


enum RealmError: Error {
    case URLNotFound
}

class ActivityManager: ObservableObject {
    private let activityActionsLimit = 50
    private var notificationToken: NotificationToken?
    @Published var activityEntries: [ActivityEntry] = []
    private var realm: Realm? = nil
    
    private func getRealm() -> Realm? {
        do {
            return try Realm(configuration: Realm.Configuration(
                fileURL: ConfigLoader.realmURL,
                deleteRealmIfMigrationNeeded: true
            ))
            
        } catch {
            error.reportToSentry()
            return nil
        }
        
    }
    
    func clean() throws {
        activityEntries = []
        let realm = getRealm()
        try realm?.write{
            realm?.deleteAll()
        }
        
        
    }
    
    func saveActivityEntry(entry: ActivityEntry) {
        
        do {
            let realm = getRealm()
            try realm?.write {
                realm?.add(entry)
            }
        } catch {
            error.reportToSentry()
        }

    }

    func updateActivityEntries() {
        guard let realm = getRealm() else {
            return
        }
        let entries = realm.objects(ActivityEntry.self).sorted(byKeyPath: "createdAt", ascending: false)

        
        var newEntries: [ActivityEntry] = []
        for i in 0..<activityActionsLimit {
            if i + 1 <= entries.count {
                newEntries.append(entries[i])
            }
            
        }
        
        DispatchQueue.main.async {
            self.activityEntries = newEntries
        }
        
    }

    func observeLatestActivityEntries() -> Void {
        if self.notificationToken == nil {
            guard let realm = getRealm() else {
                return
            }
            let result = realm.objects(ActivityEntry.self)
            self.notificationToken = result.observe{[weak self] (changes: RealmCollectionChange) in
                switch changes {
                    case .initial:
                        self?.updateActivityEntries()
                    case .update:
                        self?.updateActivityEntries()
                    case .error:
                        return
                    }
            }
        }
    }

}





class ActivityEntry: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var filename: String
    @Persisted var createdAt: Date
    @Persisted var kind: ActivityEntryOperationKind
    @Persisted var status: ActivityEntryStatus
    
    convenience init(
        filename: String,
        kind: ActivityEntryOperationKind,
        status: ActivityEntryStatus
    ) {
        self.init()
        self.filename = filename
        self.createdAt = Date()
        self.kind = kind
        self.status = status
    }
}

extension ActivityEntry: Identifiable {
    var id: String {
        return _id.stringValue
    }
}

enum ActivityEntryOperationKind: String, PersistableEnum {
    case trash
    case delete
    case download
    case upload
    case move
    case backupDownload
}

enum ActivityEntryStatus: String, PersistableEnum {
    case failed
    case finished
    case inProgress
}
