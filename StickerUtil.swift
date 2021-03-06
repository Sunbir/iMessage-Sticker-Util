//
//  StickerUtil.swift
//
//  Copyright © 2018 Sunbir Gill
//

import Messages
import UIKit

extension CGRect {

    func aspectFit(_ size: CGSize) -> CGRect {
        var result = CGRect.zero
        let aspectWidth = self.width / size.width
        let aspectHeight = self.height / size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        result.size.width = size.width * aspectRatio;
        result.size.height = size.height * aspectRatio;
        result.origin.x = (self.width - result.size.width) / 2.0;
        result.origin.y = (self.height - result.size.height) / 2.0;
        return result
    }

}

extension FileManager {

    static func getTempFilePath(_ fileExtension: String) -> String? {
        let fileName = String(format: "%@.%@", ProcessInfo.processInfo.globallyUniqueString, fileExtension)
        guard let fileUrl = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            else {
                // Failed to construct temporary file path.
                return nil
        }
        return fileUrl.path
    }

}

extension UIImage {

    func hasAlpha() -> Bool {
        guard let cgImage = self.cgImage else {
            // Fail open. I.e. if we can't determine whether the image has an alpha channel
            // we assume it does.
            return true
        }
        let alpha = cgImage.alphaInfo
        return alpha == .first
            || alpha == .last
            || alpha == .alphaOnly
            || alpha == .premultipliedFirst
            || alpha == .premultipliedLast
    }

    func resizeImageToFit(_ size: CGSize) -> UIImage? {
        let imageRect = CGRect(origin: CGPoint.zero, size: size).aspectFit(self.size)
        let imageSize = imageRect.size
        UIGraphicsBeginImageContextWithOptions(imageSize, hasAlpha(), 1.0)
        self.draw(in: CGRect(origin: CGPoint.zero, size: imageSize))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let image = result else {
            // Failed to scale image.
            return nil
        }
        return image
    }

    func createSticker(_ localizedDescription: String) throws -> MSSticker? {
        // See: https://developer.apple.com/documentation/messages
        // Ordered from largest to smallest.
        let optimalStickerDimensionsPx: [CGFloat] = [ 618.0, 408.0, 300.0 ]
        let maxStickerFileSizeBytes: Int32 = 500 * 1024

        // Find optimal sticker size.
        var stickerDimensions = self.size
        let candidateStickerDimensions = optimalStickerDimensionsPx.filter {
            $0 <= self.size.width && $0 <= self.size.height
        }
        if !candidateStickerDimensions.isEmpty {
            let stickerDimension = candidateStickerDimensions[0]
            stickerDimensions = CGSize(width: stickerDimension, height: stickerDimension)
        }
        // Aspect-fit image to optimal sticker size.
        guard let sourceImage = resizeImageToFit(stickerDimensions) else {
            // Failed to scale image.
            return nil
        }
        // Create sticker file.
        let haveAlphaChannel = hasAlpha()
        let fileExt = haveAlphaChannel ? "png" : "jpg"
        guard let filePath = FileManager.getTempFilePath(fileExt) else {
            // Failed to construct temporary file path.
            return nil
        }
        let saveSuccss = haveAlphaChannel
            ? sourceImage.saveAsPng(filePath, maxSize: maxStickerFileSizeBytes)
            : sourceImage.saveAsJpeg(filePath, maxSize: maxStickerFileSizeBytes)
        if !saveSuccss {
            // Failed to save sticker source image to file.
            return nil
        }
        // Create sticker.
        return try MSSticker(
            contentsOfFileURL: URL(fileURLWithPath: filePath),
            localizedDescription: localizedDescription)
    }

    func saveAsPng(_ filePath: String, maxSize: Int32 = Int32.max) -> Bool {
        guard let cgImage = self.cgImage, let copyOfCgImage = cgImage.copy() else {
            // Failed to get copy of underlying CGImage.
            return false
        }
        // We attempt to save the file to meet the maximum size constraint by adjusting image dimensions.
        let initialSize = self.size
        let sizeIncrementFactor: CGFloat = 0.10
        var currentSize = initialSize
        var currentImage = UIImage(cgImage: copyOfCgImage)
        while currentSize.width * currentSize.height > 0.0 {
            do {
                try UIImagePNGRepresentation(currentImage)?.write(to: URL(fileURLWithPath: filePath),
                                                                  options: .atomic)
                let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
                if let fileSize = attrs[FileAttributeKey.size] as? NSNumber {
                    if fileSize.uint64Value > maxSize {
                        currentSize = CGSize(
                            width: currentSize.width - (currentSize.width * sizeIncrementFactor),
                            height: currentSize.height - (currentSize.height * sizeIncrementFactor))
                        guard let resizedImage = currentImage.resizeImageToFit(currentSize) else {
                            // Failed to resize image.
                            return false
                        }
                        currentImage = resizedImage
                        continue
                    }
                    // The saved file is within the size limit.
                    return true
                } else {
                    // Could not read file size.
                    break
                }
            } catch {
                // Failed to save file or retrieve file attributes.
                break
            }
        }
        return false
    }

    func saveAsJpeg(_ filePath: String, maxSize: Int32 = Int32.max) -> Bool {
        // We attempt to save the file to meet the maximum size constraint by adjusting compression quality.
        let initialQuality: CGFloat = 0.9
        let qualityIncrement: CGFloat = 0.05
        var currentQuality: CGFloat = initialQuality
        while currentQuality > 0.0 {
            do {
                try UIImageJPEGRepresentation(self, currentQuality)?.write(to: URL(fileURLWithPath: filePath),
                                                                           options: .atomic)
                let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
                if let fileSize = attrs[FileAttributeKey.size] as? NSNumber {
                    if fileSize.uint64Value > maxSize {
                        currentQuality -= qualityIncrement
                        continue
                    }
                    // The saved file is within the size limit.
                    return true
                } else {
                    // Could not read file size.
                    break
                }
            } catch {
                // Failed to save file or retrieve file attributes.
                break
            }
        }
        return false
    }

}
