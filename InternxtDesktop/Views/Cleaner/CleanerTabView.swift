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
    @StateObject private var featuresService = FeaturesService.shared
    
    var body: some View {
        ZStack {
            if featuresService.isLoading {
                loadingView
            } else {
                switch cleanerService.viewState {
                case .locked:
                    LockedFeatureOverlay(isVisible: true)
                case .scanning:
                    CleanupView(cleanerService: cleanerService)
                case .results:
                    ResultsCleanerView(
                        cleanupResults: cleanerService.cleanupResult,
                        onFinish: {
                            cleanerService.backToScanning()
                        }
                    )
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
        }.onAppear{
            determineViewState()
        }
    }
    
    private func determineViewState() {
        guard featuresService.cleanerEnabled else {
            self.cleanerService.viewState =  .locked
            return
        }
        
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            AppText("Checking feature availability...")
                .font(.BaseRegular)
                .foregroundColor(.DefaultText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DefaultBackground)
    }
}

#Preview {
    CleanerTabView(cleanerService: CleanerService())
}
