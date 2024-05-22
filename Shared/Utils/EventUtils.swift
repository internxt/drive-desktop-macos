//
//  EventUtils.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 21/5/24.
//

import Foundation

struct EventsUtils {

    static func trackSuccessBackup(foldersToBackup: Int){
        let event = SuccessBackupEvent(foldersToBackup: foldersToBackup)

        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
    }

    static func trackFailureBackup(error: any Error ,foldersToBackup: Int ){
        let event = FailureBackupEvent(foldersToBackup: foldersToBackup, error: error)

        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
    }
}
