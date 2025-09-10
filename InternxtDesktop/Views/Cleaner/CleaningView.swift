//
//  CleaningView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/9/25.
//

import SwiftUI

struct CleaningView: View {
    let progress: CleanupProgress?
    let onStopCleaning: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            AppText("Cleaning...")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)
            
            AppText(progress?.currentFile ?? "...")
                 .font(.SMRegular)
                 .foregroundColor(.Gray80)
                 .lineLimit(2)
                 .truncationMode(.tail)
                 .frame(maxWidth: .infinity)
                 .frame(height: 40)
            
            VStack(spacing: 8) {
                ProgressView(value: Double(progress?.processedFiles ?? 0) / Double(max(progress?.totalFiles ?? 1, 1)))
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                    .animation(.easeInOut, value: progress?.processedFiles)
                
                AppText("\(Int((Double(progress?.processedFiles ?? 0) / Double(max(progress?.totalFiles ?? 1, 1))) * 100))%")
                    .font(.SMRegular)
                    .foregroundColor(.Gray80)
            }

            CleanupStatsView(
                deletedFiles: progress?.processedFiles ?? 0,
                freeSpaceGained: ByteCountFormatter.string(fromByteCount: Int64(progress?.freedSpace ?? 0), countStyle: .file)
            )

            AppButton(title: "Stop Clean", onClick: onStopCleaning, type: .dangerBorder)
            
        }
        .padding(.vertical,55)
        .padding(.horizontal,40)
    }
}


struct CleanupStatsView: View {
    let deletedFiles: Int
    let freeSpaceGained: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(deletedFiles)")
                    .font(.BaseMedium)
                    .foregroundColor(.Gray100)
                
                Text("Deleted files")
                    .font(.SMRegular)
                    .foregroundColor(.Gray80)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 30)
            
            VStack(spacing: 2) {
                AppText(freeSpaceGained)
                    .font(.BaseMedium)
                    .foregroundColor(.Gray100)
                
                Text("Free space gained")
                    .font(.SMRegular)
                    .foregroundColor(.Gray80)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.Surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.Gray10, lineWidth: 1)
        )
        .frame(width: 352, height: 70)
    }
}



struct ResultsCleanerView: View {
    let cleanupResults: [CleanupResult]
    let onFinish: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            
            Image("cleanerFinish")
                .resizable()
                .frame(width: 58, height: 58)
            
            AppText("Your device is clean")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)
            
            AppText("No further actions are neccessary")
                 .font(.SMRegular)
                 .foregroundColor(.Gray80)
                 .lineLimit(2)
                 .truncationMode(.tail)
                 .frame(maxWidth: .infinity)
                 .frame(height: 40)
            

            CleanupStatsView(
                deletedFiles: totalProcessedFiles,
                freeSpaceGained: ByteCountFormatter.string(fromByteCount: Int64(totalFreedSpace), countStyle: .file)
            )

            AppButton(title: "Finish", onClick: onFinish)
            
        }
        .padding(.vertical, 55)
        .padding(.horizontal, 40)
    }
    
    private var totalProcessedFiles: Int {
        cleanupResults.reduce(0) { $0 + $1.processedFiles }
    }
    
    private var totalFreedSpace: UInt64 {
        cleanupResults.reduce(0) { $0 + $1.freedSpace }
    }
}
