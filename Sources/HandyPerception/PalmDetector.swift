import CoreGraphics
import CoreML
import CoreVideo
import Foundation

extension CoreMLHandPoseProvider {
    // swiftlint:disable no_unchecked_sendable
    /// The palm detector and its input behind one serial queue, so a background search and a
    /// synchronous one never run the model at the same time.
    final class PalmDetector: @unchecked Sendable {
        // `model` and `input` are used only on `queue`; `found` and `busy` only under `lock`.
        private let model: MLModel
        private let input: CropRenderer
        private let queue = DispatchQueue(label: "dev.handy.palm-detector", qos: .userInitiated)
        private let lock = NSLock()
        private var found: [Detection] = []
        private var busy = false

        /// A frame handed to the detector's queue; the camera keeps the buffer alive until released.
        private struct Frame: @unchecked Sendable {
            let buffer: CVPixelBuffer
        }

        init(model: MLModel) throws {
            self.model = model
            input = try CropRenderer(side: CoreMLHandPoseProvider.side)
        }

        func detect(_ frame: CVPixelBuffer) throws -> [Detection] {
            let frame = Frame(buffer: frame)
            return try queue.sync { try run(frame.buffer) }
        }

        /// Looks for palms on the detector's queue unless a search is already running; `takeFound`
        /// collects what it finds.
        func detectInBackground(_ frame: CVPixelBuffer) {
            let idle = lock.withLock {
                defer { busy = true }
                return !busy
            }
            guard idle else { return }
            let frame = Frame(buffer: frame)
            queue.async { [self] in
                let detections = (try? autoreleasepool { try run(frame.buffer) }) ?? []
                lock.withLock {
                    found += detections
                    busy = false
                }
            }
        }

        func takeFound() -> [Detection] {
            lock.withLock {
                defer { found = [] }
                return found
            }
        }

        private func run(_ frame: CVPixelBuffer) throws -> [Detection] {
            let width = CVPixelBufferGetWidth(frame)
            let height = CVPixelBufferGetHeight(frame)
            let side = Double(CoreMLHandPoseProvider.side)
            // Letterbox the frame into the square input, like MediaPipe's resize-and-pad.
            let scale = side / Double(max(width, height))
            let padX = (side - Double(width) * scale) / 2
            let padY = (side - Double(height) * scale) / 2
            let squareToFrame = CGAffineTransform(scaleX: 1 / scale, y: 1 / scale).translatedBy(x: -padX, y: -padY)
            let output = try CoreMLHandPoseProvider.predict(
                model, input, frame, cropToFrame: squareToFrame, key: "detections")
            return CoreMLHandPoseProvider.decode(output, squareToFrame: squareToFrame)
        }
    }
    // swiftlint:enable no_unchecked_sendable

    /// Palm-detector rows to hand regions in frame pixels, best first, overlaps suppressed.
    static func decode(_ output: MLMultiArray, squareToFrame: CGAffineTransform) -> [Detection] {
        // Read the score column first and decode only the rows that pass: converting all 2944 × 19
        // values every frame cost more than the model itself, most of all in debug builds.
        let rows = ModelRows(output)
        var candidates: [Detection] = []
        for row in 0..<rows.count {
            let score = Double(rows[row, rows.columns - 1])
            guard score >= 0.5 else { continue }
            func value(_ column: Int) -> Float { rows[row, column] }
            // Normalised square coordinates (origin top-left) to frame pixels.
            func pixel(_ x: Float, _ y: Float) -> CGPoint {
                CGPoint(x: Double(x) * Double(side), y: Double(y) * Double(side)).applying(squareToFrame)
            }
            let topLeft = pixel(value(1), value(0))
            let bottomRight = pixel(value(3), value(2))
            let box = CGRect(
                x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
            let wrist = pixel(value(4), value(5))
            let middle = pixel(value(8), value(9))
            // MediaPipe's palm-to-hand rect: shift half a box toward the fingers, grow 2.6×.
            let rotation = atan2(wrist.y - middle.y, wrist.x - middle.x) - .pi / 2
            let size = box.width * 2.6
            let shift = CGPoint(x: -sin(rotation) * -0.5 * box.width, y: cos(rotation) * -0.5 * box.width)
            let center = CGPoint(x: box.midX + shift.x, y: box.midY + shift.y)
            candidates.append(
                Detection(region: Region(center: center, size: size, rotation: rotation), score: score, box: box))
        }
        // Non-maximum suppression.
        var kept: [Detection] = []
        for candidate in candidates.sorted(by: { $0.score > $1.score })
        where !kept.contains(where: { Self.iou($0.box, candidate.box) > 0.3 }) {
            kept.append(candidate)
        }
        return kept
    }
}
