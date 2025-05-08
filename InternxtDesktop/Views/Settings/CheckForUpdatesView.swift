//
//  CheckForUpdatesView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 19/9/23.
//

import SwiftUI
import Sparkle


final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        
        // Create our view model for our CheckForUpdatesView
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        AppButton(title: "SETTINGS_CHECK_FOR_UPDATES", onClick: checkForUpdates, type: .secondary, size: .MD).disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
    
    func checkForUpdates() {
        let wasAccessory = (NSApp.activationPolicy() == .accessory)

        if wasAccessory {
            NSApp.setActivationPolicy(.regular)
        }

        NSApp.activate(ignoringOtherApps: true)

        updater.checkForUpdates()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            for window in NSApp.windows {
                if window.title.contains("Update") || window.title.contains("Actualización") {
                    window.level = .floating
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }

  
    }
}

