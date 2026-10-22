import Foundation
import HandyCore

/// A recorded or synthesised landmark stream: numbers only, never images.
///
/// On disk (`.lmk`) it is JSON Lines: the first line is the `Header`, every following line
/// is one `LandmarkFrame`. Line-per-frame keeps live recording append-only and lets long
/// corpus files stream.
public struct LandmarkStream: Sendable, Equatable {
    public var header: Header
    public var frames: [LandmarkFrame]

    public init(header: Header, frames: [LandmarkFrame]) {
        self.header = header
        self.frames = frames
    }

    public struct Header: Sendable, Equatable, Codable {
        public static let formatName = "handy-landmarks"

        public var format: String
        public var version: Int
        /// Where the stream came from: `synth`, `vision`, `coreml` or a free-form label.
        public var source: String
        /// Optional labelled time ranges, used by the regression corpus.
        public var labels: [Label]
        /// Free-form notes such as the synth command, lighting or distance.
        public var meta: [String: String]

        public init(
            source: String, labels: [Label] = [], meta: [String: String] = [:],
            version: Int = ReplayFormat.version
        ) {
            self.format = Self.formatName
            self.version = version
            self.source = source
            self.labels = labels
            self.meta = meta
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            format = try container.decode(String.self, forKey: .format)
            version = try container.decode(Int.self, forKey: .version)
            source = try container.decode(String.self, forKey: .source)
            labels = try container.decodeIfPresent([Label].self, forKey: .labels) ?? []
            meta = try container.decodeIfPresent([String: String].self, forKey: .meta) ?? [:]
        }
    }

    public struct Label: Sendable, Equatable, Codable {
        public var start: Double
        public var end: Double
        /// A `Gesture` raw value, or `none` for footage that must fire nothing.
        public var name: String

        public init(start: Double, end: Double, name: String) {
            self.start = start
            self.end = end
            self.name = name
        }
    }
}

public enum LandmarkStreamError: Error, Equatable, CustomStringConvertible {
    case empty
    case notALandmarkStream(String)
    case unsupportedVersion(Int)
    case badFrame(line: Int, reason: String)

    public var description: String {
        switch self {
        case .empty: "file is empty"
        case .notALandmarkStream(let format):
            "format is \"\(format)\", expected \"\(LandmarkStream.Header.formatName)\""
        case .unsupportedVersion(let version):
            "version \(version) is newer than this build understands (\(ReplayFormat.version))"
        case .badFrame(let line, let reason): "line \(line): \(reason)"
        }
    }
}

extension LandmarkStream {
    public init(data: Data) throws {
        var lines = data.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true).makeIterator()
        guard let first = lines.next() else { throw LandmarkStreamError.empty }
        let decoder = JSONDecoder()
        let header = try decoder.decode(Header.self, from: Data(first))
        guard header.format == Header.formatName else { throw LandmarkStreamError.notALandmarkStream(header.format) }
        guard header.version <= ReplayFormat.version else {
            throw LandmarkStreamError.unsupportedVersion(header.version)
        }
        var frames: [LandmarkFrame] = []
        var lineNumber = 1
        while let line = lines.next() {
            lineNumber += 1
            do {
                frames.append(try decoder.decode(LandmarkFrame.self, from: Data(line)))
            } catch {
                throw LandmarkStreamError.badFrame(line: lineNumber, reason: String(describing: error))
            }
        }
        self.init(header: header, frames: frames)
    }

    /// Reads a `.lmk` file, or a `.lmkz` file (the same lines, LZFSE-compressed) for large corpora.
    public init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        try self.init(data: Self.isCompressed(url) ? try (data as NSData).decompressed(using: .lzfse) as Data : data)
    }

    /// The file extensions a landmark stream can have.
    public static let fileExtensions: Set<String> = ["lmk", "lmkz"]

    static func isCompressed(_ url: URL) -> Bool { url.pathExtension == "lmkz" }

    public func encoded() throws -> Data {
        var data = try Self.lineEncoder.encode(header)
        for frame in frames {
            data.append(UInt8(ascii: "\n"))
            data.append(try Self.lineEncoder.encode(frame))
        }
        data.append(UInt8(ascii: "\n"))
        return data
    }

    /// Writes `.lmk`, or LZFSE-compressed when the path ends in `.lmkz`.
    public func write(to url: URL) throws {
        let data = try encoded()
        try (Self.isCompressed(url) ? try (data as NSData).compressed(using: .lzfse) as Data : data)
            .write(to: url, options: .atomic)
    }

    static var lineEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

/// Appends frames to a `.lmk` file as they arrive, for recording live sessions.
public final class LandmarkStreamWriter {
    private let handle: FileHandle
    private let encoder = LandmarkStream.lineEncoder

    public init(url: URL, header: LandmarkStream.Header) throws {
        FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)
        handle = try FileHandle(forWritingTo: url)
        try handle.write(contentsOf: try encoder.encode(header) + Data("\n".utf8))
    }

    public func append(_ frame: LandmarkFrame) throws {
        try handle.write(contentsOf: try encoder.encode(frame) + Data("\n".utf8))
    }

    public func close() throws {
        try handle.close()
    }
}
