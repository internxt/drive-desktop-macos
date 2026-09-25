//
//  Issue.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/8/26.
//

import Foundation


enum IssueCategory: String, CaseIterable, Identifiable {
    case sync    = "Sync"
    case backups = "Backups"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .sync:    return NSLocalizedString("ISSUES_TAB_SYNC",    comment: "")
        case .backups: return NSLocalizedString("ISSUES_TAB_BACKUPS", comment: "")
        }
    }
}


enum IssueOperation: String {
    case upload   = "upload"
    case download = "download"
    case delete   = "delete"
    case move     = "move"
    case create   = "create"
    case trash    = "trash"

    var localizedLabel: String {
        switch self {
        case .upload:   return NSLocalizedString("ISSUE_OP_UPLOAD",   comment: "")
        case .download: return NSLocalizedString("ISSUE_OP_DOWNLOAD", comment: "")
        case .delete:   return NSLocalizedString("ISSUE_OP_DELETE",   comment: "")
        case .move:     return NSLocalizedString("ISSUE_OP_MOVE",     comment: "")
        case .create:   return NSLocalizedString("ISSUE_OP_CREATE",   comment: "")
        case .trash:    return NSLocalizedString("ISSUE_OP_TRASH",    comment: "")
        }
    }
}


struct Issue: Identifiable, Equatable {
    let id: UUID
    let category: IssueCategory
    let filename: String
    let relativePath: String?
    let operation: IssueOperation
    let errorDescription: String?
    let date: Date

    init(
        id: UUID = UUID(),
        category: IssueCategory,
        filename: String,
        relativePath: String? = nil,
        operation: IssueOperation,
        errorDescription: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.filename = filename
        self.relativePath = relativePath
        self.operation = operation
        self.errorDescription = errorDescription
        self.date = date
    }

    var userFriendlyErrorDescription: String? {
        return ErrorFormatter.userFriendlyDescription(from: errorDescription)
    }

    var fullHelpText: String {
        var parts: [String] = []
        if let path = relativePath, !path.isEmpty {
            parts.append(path)
        } else {
            parts.append(filename)
        }
        if let technical = errorDescription, !technical.isEmpty {
            parts.append(technical)
        }
        return parts.joined(separator: "\n")
    }

    static func == (lhs: Issue, rhs: Issue) -> Bool {
        lhs.id == rhs.id
    }
}



extension Issue {


    static func fromActivityEntry(_ entry: ActivityEntry) -> Issue? {
        guard entry.status == .failed else { return nil }

        let idString = entry._id.stringValue
        let stableID = UUID(uuidString: idString.padding(
            toLength: 36,
            withPad: "-",
            startingAt: 0
        )) ?? UUID()

        let operation: IssueOperation
        switch entry.kind {
        case .upload:         operation = .upload
        case .download:       operation = .download
        case .delete:         operation = .delete
        case .move:           operation = .move
        case .trash:          operation = .trash
        case .backupDownload: operation = .download
        case .backupUpload:   operation = .upload
        }

        return Issue(
            id: stableID,
            category: (entry.kind == .backupDownload || entry.kind == .backupUpload) ? .backups : .sync,
            filename: entry.filename,
            relativePath: entry.relativePath,
            operation: operation,
            errorDescription: entry.errorMessage,
            date: entry.createdAt
        )
    }
}
