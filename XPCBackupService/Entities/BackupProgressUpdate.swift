//
//  BackupProgressUpdate.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 5/4/24.
//

import Foundation

enum BackupStatus: String {
    case Idle
    case InProgress
    case Done
    case Failed
    case Stopped
}

@objc(BackupProgressUpdate) class BackupProgressUpdate: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool = true
    var completedSyncs: Int64
    var totalSyncs: Int64
    var progress: Double
    var status: BackupStatus

    init(status: BackupStatus, progress: Progress) {
        self.completedSyncs = progress.completedUnitCount
        self.totalSyncs = progress.totalUnitCount
        self.progress = progress.fractionCompleted
        self.status = status
    }
    func encode(with coder: NSCoder) {
        coder.encode(self.completedSyncs, forKey: "completedSyncs")
        coder.encode(self.totalSyncs, forKey: "totalSyncs")
        coder.encode(self.progress, forKey: "progress")
        coder.encode(self.status.rawValue, forKey: "status")
    }
    
    required init?(coder: NSCoder) {
        self.completedSyncs = coder.decodeInt64(forKey: "completedSyncs")
        self.totalSyncs = coder.decodeInt64(forKey: "totalSyncs")
        let progress = Progress(totalUnitCount: totalSyncs)
        progress.completedUnitCount = completedSyncs
        self.progress = progress.fractionCompleted
        guard let decodedStatus = coder.decodeObject(of: NSString.self,forKey: "status") else {
            self.status = .Idle
            return
        }
        
        self.status = BackupStatus(rawValue: String(decodedStatus)) ?? .Idle
    }
    
    
}
