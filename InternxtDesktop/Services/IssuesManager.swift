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
        DispatchQueue.main.async {
            self.allIssues = []
            self.logger.info("IssuesManager: all issues cleared by user (\(self.dismissedIssueIDs.count) dismissed)")
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
        for entry in entries.prefix(activityLimit) {
            guard let issue = Issue.fromActivityEntry(entry) else { continue }

            if let clearedAt = lastClearedAt, issue.date <= clearedAt {
                if dismissedIssueIDs.contains(issue.id) { continue }
            }

            built.append(issue)
        }

        DispatchQueue.main.async {
            self.allIssues = built
            self.logger.info("IssuesManager rebuilt: \(built.count) issue(s)")
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
