import Testing

@testable import FenceCheck

@Test func flagsBannedImportsInEveryForm() {
    let source = """
        import Foundation
        import AppKit
        @preconcurrency import AVFoundation
        import struct Vision.VNPoint
        public import CoreGraphics
        """
    #expect(
        violations(in: source) == [
            Violation(line: 2, module: "AppKit"),
            Violation(line: 3, module: "AVFoundation"),
            Violation(line: 4, module: "Vision"),
            Violation(line: 5, module: "CoreGraphics"),
        ])
}

@Test func allowsFoundationAndNonImportLines() {
    let source = """
        import Foundation
        // import AppKit is mentioned in a comment
        let importance = 1
        """
    #expect(violations(in: source).isEmpty)
}
