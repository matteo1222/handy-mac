import Accelerate
import CoreGraphics
import CoreVideo

/// Renders an oriented square of a camera frame into a model's 256×256 BGRA input on the CPU with
/// vImage: it converts only the part of the frame the square covers, then warps it. Core Image did
/// the same on the GPU, but each render paid ~2 ms of GPU wake-up at camera frame rates.
final class CropRenderer {
    let side: Int
    let output: CVPixelBuffer
    private var scratch: UnsafeMutableRawPointer?
    private var scratchBytes = 0
    private var conversions: [OSType: vImage_YpCbCrToARGB] = [:]

    enum Failure: Error {
        case buffer
        case vImage(vImage_Error)
    }

    init(side: Int) throws {
        self.side = side
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, side, side, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard let buffer else { throw Failure.buffer }
        output = buffer
    }

    deinit { scratch?.deallocate() }

    /// Fills `output` with the square that `cropToFrame` maps from crop pixels (origin top-left) to
    /// frame pixels (origin top-left); black where the square leaves the frame. Takes 32BGRA and
    /// 420 bi-planar (full or video range) frames.
    func render(_ frame: CVPixelBuffer, cropToFrame: CGAffineTransform) throws {
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        let square = CGRect(x: 0, y: 0, width: side, height: side).applying(cropToFrame)
        // The source rect, on even pixels so the half-resolution chroma lines up.
        let x0 = max(0, Int(square.minX.rounded(.down)) & ~1)
        let y0 = max(0, Int(square.minY.rounded(.down)) & ~1)
        let x1 = min(width, (Int(square.maxX.rounded(.up)) + 1) & ~1)
        let y1 = min(height, (Int(square.maxY.rounded(.up)) + 1) & ~1)

        CVPixelBufferLockBaseAddress(output, [])
        defer { CVPixelBufferUnlockBaseAddress(output, []) }
        var dest = vImage_Buffer(
            data: CVPixelBufferGetBaseAddress(output), height: vImagePixelCount(side), width: vImagePixelCount(side),
            rowBytes: CVPixelBufferGetBytesPerRow(output))
        var black: [UInt8] = [0, 0, 0, 255]
        guard x1 > x0, y1 > y0 else {
            try check(vImageBufferFill_ARGB8888(&dest, &black, vImage_Flags(kvImageNoFlags)))
            return
        }

        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }
        var source = try region(of: frame, x: x0, y: y0, width: x1 - x0, height: y1 - y0)
        // vImage maps source to destination with the origin bottom-left: flip the region's rows,
        // offset to frame pixels, map into the crop, flip the crop's rows.
        let flipRegion = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(y1 - y0))
        let flipCrop = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(side))
        let toCrop =
            flipRegion
            .concatenating(CGAffineTransform(translationX: Double(x0), y: Double(y0)))
            .concatenating(cropToFrame.inverted()).concatenating(flipCrop)
        var transform = vImage_AffineTransform_Double(
            a: toCrop.a, b: toCrop.b, c: toCrop.c, d: toCrop.d, tx: toCrop.tx, ty: toCrop.ty)
        try check(
            vImageAffineWarpD_ARGB8888(
                &source, &dest, nil, &transform, &black, vImage_Flags(kvImageBackgroundColorFill)))
    }

    /// The frame's pixels in the given rect as BGRA: in place for BGRA frames, converted into the
    /// scratch buffer for YUV ones.
    private func region(of frame: CVPixelBuffer, x: Int, y: Int, width: Int, height: Int) throws -> vImage_Buffer {
        let format = CVPixelBufferGetPixelFormatType(frame)
        if format == kCVPixelFormatType_32BGRA {
            guard let base = CVPixelBufferGetBaseAddress(frame) else { throw Failure.buffer }
            let rowBytes = CVPixelBufferGetBytesPerRow(frame)
            return vImage_Buffer(
                data: base + y * rowBytes + x * 4, height: vImagePixelCount(height), width: vImagePixelCount(width),
                rowBytes: rowBytes)
        }
        guard CVPixelBufferGetPlaneCount(frame) == 2,
            let luma = CVPixelBufferGetBaseAddressOfPlane(frame, 0),
            let chroma = CVPixelBufferGetBaseAddressOfPlane(frame, 1)
        else { throw Failure.buffer }
        let lumaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 0)
        let chromaRow = CVPixelBufferGetBytesPerRowOfPlane(frame, 1)
        var yPlane = vImage_Buffer(
            data: luma + y * lumaRow + x, height: vImagePixelCount(height), width: vImagePixelCount(width),
            rowBytes: lumaRow)
        var cbcrPlane = vImage_Buffer(
            data: chroma + y / 2 * chromaRow + x, height: vImagePixelCount(height / 2),
            width: vImagePixelCount(width / 2), rowBytes: chromaRow)
        let bytes = width * height * 4
        if bytes > scratchBytes {
            scratch?.deallocate()
            scratch = UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 64)
            scratchBytes = bytes
        }
        var rgb = vImage_Buffer(
            data: scratch, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * 4)
        var conversion = try self.conversion(for: format, bt709: Self.is709(frame))
        // ARGB channel order 3, 2, 1, 0 writes BGRA.
        var permute: [UInt8] = [3, 2, 1, 0]
        try check(
            vImageConvert_420Yp8_CbCr8ToARGB8888(
                &yPlane, &cbcrPlane, &rgb, &conversion, &permute, 255, vImage_Flags(kvImageNoFlags)))
        return rgb
    }

    /// BT.709 when the frame says so, else BT.601 (vImage's own constants are mutable globals).
    private static func is709(_ frame: CVPixelBuffer) -> Bool {
        let tag = CVBufferCopyAttachment(frame, kCVImageBufferYCbCrMatrixKey, nil) as? String
        return tag == (kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String)
    }

    private func conversion(for format: OSType, bt709: Bool) throws -> vImage_YpCbCrToARGB {
        let key = format ^ (bt709 ? 0x8000_0000 : 0)
        if let cached = conversions[key] { return cached }
        var matrix =
            bt709
            ? vImage_YpCbCrToARGBMatrix(Yp: 1, Cr_R: 1.5748, Cr_G: -0.468124, Cb_G: -0.187324, Cb_B: 1.8556)
            : vImage_YpCbCrToARGBMatrix(Yp: 1, Cr_R: 1.402, Cr_G: -0.714136, Cb_G: -0.344136, Cb_B: 1.772)
        var range =
            format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ? vImage_YpCbCrPixelRange(
                Yp_bias: 0, CbCr_bias: 128, YpRangeMax: 255, CbCrRangeMax: 255, YpMax: 255, YpMin: 0, CbCrMax: 255,
                CbCrMin: 0)
            : vImage_YpCbCrPixelRange(
                Yp_bias: 16, CbCr_bias: 128, YpRangeMax: 235, CbCrRangeMax: 240, YpMax: 235, YpMin: 16,
                CbCrMax: 240, CbCrMin: 16)
        var conversion = vImage_YpCbCrToARGB()
        try check(
            vImageConvert_YpCbCrToARGB_GenerateConversion(
                &matrix, &range, &conversion, kvImage420Yp8_CbCr8, kvImageARGB8888, vImage_Flags(kvImageNoFlags)))
        conversions[key] = conversion
        return conversion
    }

    private func check(_ error: vImage_Error) throws {
        guard error == kvImageNoError else { throw Failure.vImage(error) }
    }
}
