import CoreImage
import CoreVideo
import Testing

@testable import HandyPerception

/// The vImage crop matches what Core Image rendered for the same square: the palm detector's
/// letterbox and a rotated hand crop, from BGRA and from the camera's YUV.
@Test(arguments: [false, true])
func cropRendererMatchesCoreImage(yuv: Bool) throws {
    let bgra = try #require(SampleHandImage.pixelBuffer("✋", mirrored: true))
    let frame = yuv ? try #require(convert(bgra, to: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)) : bgra
    let width = Double(CVPixelBufferGetWidth(frame))
    let height = Double(CVPixelBufferGetHeight(frame))
    let side = 256.0
    let scale = side / max(width, height)
    let letterbox = CGAffineTransform(scaleX: 1 / scale, y: 1 / scale)
        .translatedBy(x: -(side - width * scale) / 2, y: -(side - height * scale) / 2)
    let region = CoreMLHandPoseProvider.Region(center: CGPoint(x: 420, y: 380), size: 520, rotation: 0.4)
    let renderer = try CropRenderer(side: 256)
    for cropToFrame in [letterbox, region.cropToFrame] {
        try renderer.render(frame, cropToFrame: cropToFrame)
        let reference = try #require(coreImageCrop(frame, cropToFrame: cropToFrame, side: 256))
        let difference = meanDifference(renderer.output, reference)
        if let dir = ProcessInfo.processInfo.environment["CROP_DUMP"] {
            for (name, buffer) in [("vimage", renderer.output), ("ci", reference)] {
                let url = URL(filePath: dir).appending(path: "\(name)-\(yuv)-\(cropToFrame.a).png")
                try CIContext().writePNGRepresentation(
                    of: CIImage(cvPixelBuffer: buffer), to: url, format: .RGBA8,
                    colorSpace: CGColorSpaceCreateDeviceRGB())
            }
        }
        #expect(difference < 4, "mean channel difference \(difference) of 255")
    }
}

/// What CoreMLHandPoseProvider rendered with Core Image: y-up, so flip into and out of the crop.
private func coreImageCrop(_ frame: CVPixelBuffer, cropToFrame: CGAffineTransform, side: Int) -> CVPixelBuffer? {
    let height = Double(CVPixelBufferGetHeight(frame))
    let flipFrame = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
    let flipCrop = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(side))
    let toCrop = flipFrame.concatenating(cropToFrame.inverted()).concatenating(flipCrop)
    let square = CGRect(x: 0, y: 0, width: side, height: side)
    let image = CIImage(cvPixelBuffer: frame).transformed(by: toCrop).cropped(to: square)
        .composited(over: CIImage(color: .black).cropped(to: square))
    var out: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, side, side, kCVPixelFormatType_32BGRA, nil, &out)
    guard let out else { return nil }
    CIContext().render(image, to: out)
    return out
}

private func convert(_ buffer: CVPixelBuffer, to format: OSType) -> CVPixelBuffer? {
    var out: CVPixelBuffer?
    CVPixelBufferCreate(
        kCFAllocatorDefault, CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), format,
        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &out)
    guard let out else { return nil }
    CIContext().render(CIImage(cvPixelBuffer: buffer), to: out)
    return out
}

private func meanDifference(_ a: CVPixelBuffer, _ b: CVPixelBuffer) -> Double {
    CVPixelBufferLockBaseAddress(a, .readOnly)
    CVPixelBufferLockBaseAddress(b, .readOnly)
    defer {
        CVPixelBufferUnlockBaseAddress(a, .readOnly)
        CVPixelBufferUnlockBaseAddress(b, .readOnly)
    }
    guard let pa = CVPixelBufferGetBaseAddress(a), let pb = CVPixelBufferGetBaseAddress(b) else { return .infinity }
    let (rowA, rowB) = (CVPixelBufferGetBytesPerRow(a), CVPixelBufferGetBytesPerRow(b))
    var total = 0
    for y in 0..<CVPixelBufferGetHeight(a) {
        for x in 0..<CVPixelBufferGetWidth(a) * 4 where x % 4 != 3 {
            total += abs(
                Int(pa.load(fromByteOffset: y * rowA + x, as: UInt8.self))
                    - Int(pb.load(fromByteOffset: y * rowB + x, as: UInt8.self)))
        }
    }
    return Double(total) / Double(CVPixelBufferGetHeight(a) * CVPixelBufferGetWidth(a) * 3)
}
