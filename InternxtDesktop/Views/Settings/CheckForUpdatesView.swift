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
        AppButton(title: "SETTINGS_CHECK_FOR_UPDATES", onClick: updater.checkForUpdates, type: .secondary, size: .MD).disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

