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
    @Published var isSyncing: Bool = false
    private var lastEntryCount: Int = 0
    private var syncDebouncer: Timer?
    private let syncDebounceInterval: TimeInterval = 5.0
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
    
    private func setSyncing(_ syncing: Bool) {
        if isSyncing != syncing {
            isSyncing = syncing
        }
    }
    
    private func activityDidOccur() {
        DispatchQueue.main.async {
            self.setSyncing(true)
            
            self.syncDebouncer?.invalidate()
            self.syncDebouncer = Timer.scheduledTimer(withTimeInterval: self.syncDebounceInterval, repeats: false) { [weak self] _ in
                self?.setSyncing(false)
            }
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
         activityDidOccur()
         
         do {
             let realm = getRealm()
             try realm?.write {
                 realm?.add(entry, update: .modified)
             }
         } catch {
             error.reportToSentry()
         }
     }

    func updateActivityEntries() {
        guard let realm = getRealm() else { return }
        
        let entries = realm.objects(ActivityEntry.self).sorted(byKeyPath: "createdAt", ascending: false)

        let newEntries = Array(entries.prefix(activityActionsLimit))
        
        DispatchQueue.main.async {
            self.activityEntries = newEntries
        }
    }
    
    func observeLatestActivityEntries() {
        guard let realm = getRealm() else { return }
        
        let result = realm.objects(ActivityEntry.self)
        
        self.notificationToken = result.observe { [weak self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                self?.updateActivityEntries()
            case .update:
                self?.updateActivityEntries()
                self?.activityDidOccur()
            case .error(let error):
                error.reportToSentry()
                return
            }
        }
    }

    deinit {
         notificationToken?.invalidate()
         syncDebouncer?.invalidate()
     }

}





class ActivityEntry: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var filename: String
    @Persisted var createdAt: Date
    @Persisted var kind: ActivityEntryOperationKind
    @Persisted var status: ActivityEntryStatus
    
    convenience init(
        _id: ObjectId? = nil,
        filename: String,
        kind: ActivityEntryOperationKind,
        status: ActivityEntryStatus
    ) {
        self.init()
        self._id = _id ?? ObjectId.generate()
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
