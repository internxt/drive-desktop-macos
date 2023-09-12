//
//  GlobalUIManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 5/9/23.
//

import Foundation


enum AppStatus {
    case loading
    case failedToInit
    case ready
}
class GlobalUIManager: ObservableObject {
    @Published var appStatus: AppStatus = .loading
    @Published var widgetIsOpen: Bool = false
    
    func setWidgetIsOpen(_ widgetIsOpen: Bool) {
        self.widgetIsOpen = widgetIsOpen
    }
    
    func setAppStatus(_ appStatus: AppStatus) {
        self.appStatus = appStatus
    }
}
