//
//  ThumbnailGenerator.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import Foundation
import QuickLookThumbnailing
import ImageIO

class ThumbnailGenerator {
    static var shared = ThumbnailGenerator()
    private var defaultThumbnailSize:CGFloat = 512
    func generateThumbnail(for fileURL: URL, destinationURL: URL ,size: CGSize) async throws -> URL {
        
        let originalDimensions = getImageDimensions(url: fileURL)
        
        var idealSize = CGSize(
            width: self.defaultThumbnailSize,
            height: self.defaultThumbnailSize
        )
        
        if let originalDimensions = originalDimensions {
            let isHorizontal = originalDimensions.width >= originalDimensions.height

            if isHorizontal {
                let idealHeight = (self.defaultThumbnailSize * originalDimensions.height) / originalDimensions.width
                // Generate height maintaining aspect ratio
                idealSize = CGSize(width: self.defaultThumbnailSize, height: idealHeight)
            } else {
                let idealWidth = (self.defaultThumbnailSize * originalDimensions.width) / originalDimensions.height
                // Generate width maintaining aspect ratio
                idealSize = CGSize(width: idealWidth, height: self.defaultThumbnailSize)
            }
        }
        
        let request = QLThumbnailGenerator
            .Request(fileAt: fileURL, size: idealSize, scale: 1.0,
                     representationTypes: .thumbnail)
        
        try await QLThumbnailGenerator.shared.saveBestRepresentation(for: request, to: destinationURL, contentType: UTType.jpeg.identifier)
        
        return destinationURL
    }
    
    private func getImageDimensions(url: URL) -> CGSize? {
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as Dictionary? {
                let width = imageProperties[kCGImagePropertyPixelWidth] as? Int
                let height = imageProperties[kCGImagePropertyPixelHeight] as? Int
                if width == nil || height == nil {
                    return nil
                }
                return CGSize(width: width!, height: height!)
            }
        }
        return nil
    }
}
