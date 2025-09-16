//
//  CleanerTabView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 7/8/25.
//

import SwiftUI

enum CleanerViewState {
    case locked
    case scanning
    case results
    case cleaning
}

struct CleanerTabView: View {
    @StateObject var cleanerService: CleanerService
    
      
    var body: some View {
        ZStack {
            switch cleanerService.viewState {
            case .locked:
                LockedFeatureOverlay(isVisible: true)
            case .scanning:
                CleanupView(
                    cleanerService: cleanerService)
            case .results:
                ResultsCleanerView( cleanupResults: cleanerService.cleanupResult,
                onFinish: {
                    cleanerService.backToScanning()
                })
            case .cleaning:
                CleaningView(
                    progress: cleanerService.currentCleaningProgress,
                    onStopCleaning: {
                        Task {
                            await cleanerService.cancelCurrentOperation()
                        }
                       
                    }
                )
            }
        }
    }
}
#Preview {
    CleanerTabView(cleanerService: CleanerService())
}
