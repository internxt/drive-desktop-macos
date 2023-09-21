//
//  AccountUsageView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 5/9/23.
//

import SwiftUI

let MIN_SEGMENT_WIDTH: Int64 = 6;
struct AccountUsageView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var usageManager: UsageManager
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                CurrentPlanSpace()
                Spacer()
                AppButton(title: "COMMON_UPGRADE", onClick: handleOpenUpgradePlan)
            }.padding(.bottom, 20)
            HStack {
                Text("COMMON_USAGE_\(usageManager.getFormattedTotalUsage())_OF_\(usageManager.format(bytes: usageManager.limit))").font(.BaseRegular)
                    .foregroundColor(.Gray100)
                Spacer()
                AppText("\(usageManager.getUsedPercentage())")
                    .font(.BaseRegular)
                    .foregroundColor(.Gray50)
            }
            
            
            UsageBar().cornerRadius(6).padding(.vertical, 8)
            HStack(alignment: .center, spacing: 16) {
                UsageLegendItem(label: "Drive", color: .Primary)
                UsageLegendItem(label: "Backups", color: .Indigo)
                UsageLegendItem(label: "Photos", color: .Orange)
            }
        }
        
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color("Gray5") :  Color("Surface"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .inset(by: -0.5)
                .stroke(Color("Gray10"), lineWidth: 1)
        )
    }
    
    
    func CurrentPlanSpace() -> some View {
        let (number, suffix) = usageManager.formatParts(bytes: usageManager.limit)
        return HStack(alignment:.firstTextBaseline, spacing: 2) {
            AppText(number).font(.XXXLMedium)
            AppText(suffix).font(.XXLMedium)
        }
    }
    func UsageLegendItem(label: String, color: Color) -> some View {
        return HStack(alignment: .center, spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            AppText(label).font(.SMRegular)
        }
    }
    
    func UsageBar() -> some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 0) {
                DriveUsageSegment(totalWidth: proxy.size.width)
                BackupsUsageSegment(totalWidth: proxy.size.width)
                PhotosUsageSegment(totalWidth: proxy.size.width)
                Spacer()
            }
        }
        .frame( maxWidth: .infinity, maxHeight: 24)
        .background(colorScheme == .dark ?  Color("Surface") : Color("Gray5"))
        
    }
    
    func BackupsUsageSegment(totalWidth: CGFloat) -> some View {
        
        func getWidth() -> Int64 {
            
            if usageManager.backupsUsage == 0 {
                return 0
            }
            
            let segmentWidth = (usageManager.backupsUsage * Int64(totalWidth)) / usageManager.limit
            
            return segmentWidth < MIN_SEGMENT_WIDTH ? MIN_SEGMENT_WIDTH : segmentWidth
        }
        
        
        return Rectangle()
            .fill(Color("Indigo"))
            .frame(maxWidth: CGFloat(getWidth()), maxHeight: .infinity)
            .overlay(Rectangle()
                .frame(width: 2, height: nil, alignment: .trailing).foregroundColor(Color("Surface")), alignment: .trailing)
    }
    
    func DriveUsageSegment(totalWidth: CGFloat) -> some View {
        func getWidth() -> Int64 {
            
            if usageManager.driveUsage == 0 {
                return 0
            }
            
            let segmentWidth = (usageManager.driveUsage * Int64(totalWidth)) / usageManager.limit
            
            return segmentWidth < MIN_SEGMENT_WIDTH ? MIN_SEGMENT_WIDTH : segmentWidth
        }
        
        
        
        return Rectangle()
            .fill(Color("Primary"))
            .frame(maxWidth: CGFloat(getWidth()), maxHeight: .infinity)
            

            .overlay(Rectangle()
                .frame(width: 2, height: nil, alignment: .trailing).foregroundColor(Color("Surface")), alignment: .trailing)

    }
    
    func handleOpenUpgradePlan() {
        URLDictionary.UPGRADE_PLAN.open()
    }
    
    func PhotosUsageSegment(totalWidth: CGFloat) -> some View {
        
        func getWidth() -> Int64 {
            
            if usageManager.photosUsage == 0 {
                return 0
            }
            
            let segmentWidth = (usageManager.photosUsage * Int64(totalWidth)) / usageManager.limit
            
            return segmentWidth < MIN_SEGMENT_WIDTH ? MIN_SEGMENT_WIDTH : segmentWidth
        }
        
        return  Rectangle()
            .fill(Color("Orange"))
            .frame(
                maxWidth: CGFloat(getWidth()),
                maxHeight: .infinity
            ).overlay(Rectangle()
                .frame(width: 2, height: nil, alignment: .trailing).foregroundColor(Color("Surface")), alignment: .trailing)
            
    }
}

struct AccountUsageView_Previews: PreviewProvider {
    static var previews: some View {
        AccountUsageView().frame(width: 400).environmentObject(UsageManager())
    }
}
