//
//  Analytics.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import Foundation
import Rudder





struct Analytics {
    let client: RSClient = {
        RSClient.sharedInstance()
    }()
    
    
    static let shared: Analytics = {
        let instance = Analytics()
        return instance
    }()

    private func getAppContextProperties() -> [String: String] {
        return [
            "name": "drive-desktop",
            "isNativeMacOS": "1",
            "version": "\(Bundle.main.releaseVersionNumber ?? "NO_RELEASE_VERSION_NUMBER").\(Bundle.main.buildVersionNumber ?? "NO_BUILD_VERSION_NUMBER")"
        ]
        
    }

    private func getOSContextProperties() -> [String: String] {
        return [
            "family": "darwin",
            "name": "Darwin",
            "short_name": "MAC",
            "version": ProcessInfo.processInfo.formattedOSVersion()
        ]
        
    }
    
    init() {
        let config: RSConfig = RSConfig(writeKey: ConfigLoader.shared.get().RUDDERSTACK_WRITE_KEY)
            .dataPlaneURL(ConfigLoader.shared.get().RUDDERSTACK_DATA_PLANE_URL)
                          .trackLifecycleEvents(true)
                          .recordScreenViews(true)
                
        RSClient.sharedInstance().configure(with: config)
    }
    
    func identify(userId: String, email: String) {
        client.identify(
            userId,
            traits: ["email":email]
        )
    }
        
    
    func track(key: AnalyticsEvent, props: [String: String]) {
        client.track(key.rawValue, properties: [
            "app": getAppContextProperties(),
            "os": getOSContextProperties()
        ].merging(props){ (_, new) in new })
    }
    
    func track(event: UploadAnalyticsEventPayload) {
        client.track(event.eventName.rawValue, properties: [
            "app": getAppContextProperties(),
            "os": getOSContextProperties()
        ].merging(event.getAllProperties()){ (_, new) in new })
    }
    
    func track(event: DownloadAnalyticsEventPayload) {
        client.track(event.eventName.rawValue, properties: [
            "app": getAppContextProperties(),
            "os": getOSContextProperties()
        ].merging(event.getAllProperties()){ (_, new) in new })
    }
    
    func track(event: BackupEventPayload) {
        client.track(event.eventName.rawValue, properties: [
            "app": getAppContextProperties(),
            "os": getOSContextProperties()
        ].merging(event.getAllProperties()){ (_, new) in new })
    }

}
