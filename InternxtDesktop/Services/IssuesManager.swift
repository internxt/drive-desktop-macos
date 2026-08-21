//
//  IssuesManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/8/26.
//

import Foundation
import Combine
import RealmSwift


class IssuesManager: ObservableObject {

    @Published private(set) var allIssues: [Issue] = []


    var totalIssueCount: Int {
        allIssues.count
    }

   

    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "IssuesManager")
    private var notificationToken: NotificationToken?
    private let activityLimit = 200


    private var dismissedKeys: Set<String> = []
    private var dismissedIssueIDs: Set<UUID> = []

    private var lastClearedAt: Date? = nil

   

    init() {}

    deinit {
        notificationToken?.invalidate()
    }


    func startObserving() {
        guard notificationToken == nil else { return }
        guard let realm = getRealm() else {
            logger.error("IssuesManager: cannot open Realm, issues will not be observed")
            return
        }

        let results = realm.objects(ActivityEntry.self)
        notificationToken = results.observe { [weak self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial, .update:
                self?.rebuildIssues(realm: realm)
            case .error(let error):
                self?.logger.error("IssuesManager Realm observe error: \(error)")
            }
        }
        logger.info("IssuesManager started observing ActivityEntry changes")
    }


    func clearAll() {
        lastClearedAt = Date()
        dismissedIssueIDs = Set(allIssues.map { $0.id })
        dismissedKeys = Set(allIssues.map { "\($0.category.rawValue)_\($0.filename)_\($0.operation.rawValue)" })
        DispatchQueue.main.async {
            self.allIssues = []
            self.logger.info("IssuesManager: all issues cleared by user (\(self.dismissedKeys.count) unique item(s) dismissed)")
        }
    }

 
    func issues(for category: IssueCategory) -> [Issue] {
        allIssues.filter { $0.category == category }
    }



    private func rebuildIssues(realm: Realm) {
        let entries = realm
            .objects(ActivityEntry.self)
            .filter("status == %@", ActivityEntryStatus.failed.rawValue)
            .sorted(byKeyPath: "createdAt", ascending: false)

        var built: [Issue] = []
        var seenKeys = Set<String>()

        for entry in entries.prefix(activityLimit) {
            guard let issue = Issue.fromActivityEntry(entry) else { continue }

         
            let deduplicationKey = "\(issue.category.rawValue)_\(issue.filename)_\(issue.operation.rawValue)"

            // Since entries are sorted newest first, skip older retry attempts of the same file
            guard !seenKeys.contains(deduplicationKey) else { continue }

            // Check if there is a more recent successful entry for this file (auto-resolution on retry success)
            let hasMoreRecentSuccess = realm
                .objects(ActivityEntry.self)
                .filter("filename == %@ AND status == %@ AND createdAt >= %@", entry.filename, ActivityEntryStatus.finished.rawValue, entry.createdAt)
                .first != nil

            if hasMoreRecentSuccess {
                continue
            }

            if dismissedKeys.contains(deduplicationKey) || dismissedIssueIDs.contains(issue.id) {
                continue
            }

            seenKeys.insert(deduplicationKey)
            built.append(issue)
        }

        DispatchQueue.main.async {
            self.allIssues = built
            self.logger.info("IssuesManager rebuilt: \(built.count) unique issue(s)")
        }
    }

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
}
