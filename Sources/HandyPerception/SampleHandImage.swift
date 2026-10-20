import CoreGraphics
import CoreText
import CoreVideo
import Foundation

/// Renders a hand emoji into a camera-sized frame. Vision finds all 21 joints on Apple's
/// ✋ 👍 🤏 🤙 glyphs, which gives tests and benches a real backend input without a camera.
/// `mirrored` flips the frame like the live camera path does before Vision sees it.
public enum SampleHandImage {
    public static func cgImage(
        _ emoji: String = "✋", width: Int = 1280, height: Int = 720, at x: Double = 380, mirrored: Bool = false
    ) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else { return nil }
        context.setFillColor(gray: 0.85, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if mirrored {
            context.translateBy(x: Double(width), y: 0)
            context.scaleBy(x: -1, y: 1)
        }
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, 420 * Double(height) / 720, nil)
        let text = NSAttributedString(string: emoji, attributes: [.init(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(text)
        context.textPosition = CGPoint(x: x * Double(height) / 720, y: 110 * Double(height) / 720)
        CTLineDraw(line, context)
        return context.makeImage()
    }

    /// The same frame as a 32BGRA pixel buffer, as a camera would deliver it.
    public static func pixelBuffer(
        _ emoji: String = "✋", width: Int = 1280, height: Int = 720, mirrored: Bool = false
    ) -> CVPixelBuffer? {
        guard let image = cgImage(emoji, width: width, height: height, mirrored: mirrored) else { return nil }
        var buffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
