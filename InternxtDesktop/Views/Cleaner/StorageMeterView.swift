//
//  StorageMeterView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//
//

import Foundation
import SwiftUI

struct StorageMeterView: View {
    let scanResult: ScanResult?
    let selectedCategories: Set<String>

    var totalStorage: Double {
        guard let result = scanResult else { return 0 }
        return Double(result.totalSize) / (1024 * 1024 * 1024)
    }

    var categories: [StorageCategory] {
        guard let result = scanResult else { return [] }

        let colors: [Color] = [.blue, .orange, .pink, .purple, .green, .red, .cyan, .yellow]

        return result.categories.enumerated().map { index, category in
            let isSelected = selectedCategories.contains(category.id)
            let baseColor = colors[index % colors.count]
            
            return StorageCategory(
                id: category.id,
                name: category.name,
                value: Double(category.size) / (1024 * 1024 * 1024),
                color: isSelected ? baseColor : Color.gray.opacity(0.4)
            )
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                AppText("Select a category to\npreview content")
                     .font(.BaseRegular)
                     .foregroundColor(.DefaultText)
                     .lineLimit(2)
                     .truncationMode(.tail)
                     .multilineTextAlignment(.center)

                ZStack {
                    if categories.isEmpty {
                        Circle()
                            .trim(from: 0, to: 0.5)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(180))
                    } else {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            let angles = getSegmentAngles(for: index)
                            Circle()
                                .trim(from: angles.start, to: angles.end)
                                .stroke(category.color, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(180))
                        }
                    }

                    VStack(spacing: 8) {
                        AppText(String(format: "%.1f GB", totalStorage))
                            .font(.XXLSemibold)
                            .foregroundColor(.DefaultTextStrong)

                        if scanResult != nil {
                            AppText("Save up to 7% of your space")
                                .font(.XSRegular)
                                .foregroundColor(.DefaultText)
                                .multilineTextAlignment(.center)
                        } else {
                            AppText("Scanning...")
                                .font(.XSRegular)
                                .foregroundColor(.DefaultText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .offset(y: -20)
                }
                .padding(.horizontal, 40)
            }
        }
    }

    private func getSegmentAngles(for index: Int) -> (start: CGFloat, end: CGFloat) {
        guard !categories.isEmpty else { return (0, 0) }
        
        let totalValue = categories.reduce(0) { $0 + $1.value }
        guard totalValue > 0 else { return (0, 0) }
        
        // Configuración ajustada para gaps mínimos como en Figma
        let gapSize: CGFloat = 0.008 // Gap muy pequeño para coincidir con el diseño de Figma
        let totalGaps = CGFloat(categories.count - 1) * gapSize
        let availableSpace: CGFloat = 0.5 - totalGaps
        
        // Calcular tamaño mínimo para segmentos muy pequeños
        let minSegmentSize = availableSpace / CGFloat(categories.count) * 0.15 // 15% del tamaño promedio
        
        // Determinar valores ajustados para cada categoría
        var adjustedValues: [Double] = []
        var totalAdjusted: Double = 0
        
        for category in categories {
            let proportionalSize = CGFloat(category.value / totalValue) * availableSpace
            if proportionalSize < minSegmentSize {
                // Asignar tamaño mínimo a segmentos muy pequeños
                let adjustedValue = Double(minSegmentSize / availableSpace) * totalValue
                adjustedValues.append(adjustedValue)
                totalAdjusted += adjustedValue
            } else {
                adjustedValues.append(category.value)
                totalAdjusted += category.value
            }
        }
        
        // Calcular posición del segmento actual
        var accumulatedBefore: Double = 0
        for i in 0..<index {
            accumulatedBefore += adjustedValues[i]
        }
        
        let currentSegmentValue = adjustedValues[index]
        
        // Calcular posiciones sin gaps primero
        let startPercent = CGFloat(accumulatedBefore / totalAdjusted) * availableSpace
        let endPercent = CGFloat((accumulatedBefore + currentSegmentValue) / totalAdjusted) * availableSpace
        
        // Aplicar gaps acumulados correctamente
        let gapsBeforeSegment = CGFloat(index) * gapSize
        
        return (
            start: startPercent + gapsBeforeSegment,
            end: endPercent + gapsBeforeSegment
        )
    }
}

struct StorageCategory {
    let id: String
    let name: String
    let value: Double
    let color: Color
}
