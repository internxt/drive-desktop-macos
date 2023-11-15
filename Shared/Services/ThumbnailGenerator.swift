//
//  ThumbnailGenerator.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import Foundation
import QuickLookThumbnailing
import ImageIO

struct GeneratedThumbnailResult {
    public let width: Int
    public let height: Int
    public let url: URL
}

var DEFAULT_THUMBNAIL_SIZE: CGFloat = 512
class ThumbnailGenerator {
    static var shared = ThumbnailGenerator()
    
    func generateThumbnail(for fileURL: URL, destinationURL: URL ,size: CGFloat = DEFAULT_THUMBNAIL_SIZE) async throws -> GeneratedThumbnailResult {
        
        let originalDimensions = getImageDimensions(url: fileURL)
        
        var idealSize = CGSize(
            width: size,
            height: size
        )
        
        if let originalDimensions = originalDimensions {
            let isHorizontal = originalDimensions.width >= originalDimensions.height

            if isHorizontal {
                let idealHeight = (size * originalDimensions.height) / originalDimensions.width
                // Generate height maintaining aspect ratio
                idealSize = CGSize(width: size, height: idealHeight)
            } else {
                let idealWidth = (size * originalDimensions.width) / originalDimensions.height
                // Generate width maintaining aspect ratio
                idealSize = CGSize(width: idealWidth, height: size)
            }
        }
        
        let request = QLThumbnailGenerator
            .Request(fileAt: fileURL, size: idealSize, scale: 1.0,
                     representationTypes: .thumbnail)
        
        try await QLThumbnailGenerator.shared.saveBestRepresentation(for: request, to: destinationURL, contentType: UTType.jpeg.identifier)
        
        return GeneratedThumbnailResult(width: Int(idealSize.width), height: Int(idealSize.height), url: destinationURL)
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
