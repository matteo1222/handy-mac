import AppKit
import HandyCore
import SwiftUI

/// Renders Handy's own views to PNG for `handyctl screenshot`, without Screen Recording permission.
@MainActor
enum Screenshots {
    enum Failure: Error, CustomStringConvertible {
        case unknownTarget(String)
        case renderFailed

        var description: String {
            switch self {
            case .unknownTarget(let target): "unknown target \(target); use \(targets.joined(separator: ", "))"
            case .renderFailed: "rendering produced no image"
            }
        }
    }

    /// The view a target names. `onboarding:<step>` picks one tutorial step.
    static func view(for target: String, model: AppModel) throws -> AnyView {
        if target.hasPrefix("onboarding:") {
            guard let step = Tutorial.Step(rawValue: String(target.dropFirst("onboarding:".count))) else {
                throw Failure.unknownTarget(target)
            }
            return AnyView(OnboardingView(model: .preview(at: step)))
        }
        let views: [String: () -> AnyView] = [
            "hud": { AnyView(HUDView(state: model.currentHUD).padding(12)) },
            "hud-gallery": { AnyView(HUDGallery().padding(12)) },
            "onboarding": { AnyView(OnboardingContactSheet()) },
            "palette": { AnyView(PaletteView(layout: model.settings.palette.standard, highlighted: 2)) },
            "settings": { AnyView(SettingsView(model: model)) },
            "cursor-ring": {
                AnyView(
                    HStack {
                        ForEach([0.0, 0.33, 0.66, 1.0], id: \.self) { closeness in
                            CursorRingView(closeness: closeness, pressed: closeness == 1)
                        }
                    }.padding(12))
            },
        ]
        guard let make = views[target] else { throw Failure.unknownTarget(target) }
        return make()
    }

    nonisolated static let targets = [
        "hud", "hud-gallery", "cursor-ring", "settings", "onboarding", "onboarding:<step>", "palette",
    ]

    static func render(_ target: String, model: AppModel, to url: URL) throws {
        let view = try self.view(for: target, model: model)
        // Draw through AppKit so materials and glass render as they do on screen.
        let host = NSHostingView(
            rootView: view.environment(\.drawsSolidPill, true).background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSApp.effectiveAppearance
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw Failure.renderFailed }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw Failure.renderFailed }
        try data.write(to: url)
    }
}

/// Every HUD state in one column, for visual review.
struct HUDGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.states.enumerated()), id: \.offset) { _, state in HUDView(state: state) }
        }
    }

    static let states: [HUDState] = [
        .make(status: .init(mode: .off, progress: nil), lastAction: nil, problem: nil),
        .make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: nil),
        .make(status: .init(mode: .arming, progress: 0.35), lastAction: nil, problem: nil),
        .make(status: .init(mode: .arming, progress: 0.8), lastAction: nil, problem: nil),
        .make(status: .init(mode: .engaged, progress: nil), lastAction: "Double click", problem: nil),
        .make(status: .init(mode: .dragging, progress: nil), lastAction: nil, problem: nil),
        .make(status: .init(mode: .scrolling, progress: nil), lastAction: nil, problem: nil),
        .make(
            status: .init(mode: .watching, progress: 0.6, oneShot: .thumbsUp), lastAction: nil, problem: nil,
            binding: "Return"),
        .make(status: .init(mode: .watching, progress: nil), lastAction: "Return", problem: nil),
        .make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: .cameraInUse),
        .make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: .cameraDisconnected),
        .make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: .tooDark),
        .make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: .accessibilityNeeded),
        .make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: .dictationUnavailable),
    ]
}

/// Every onboarding step side by side, for visual review.
struct OnboardingContactSheet: View {
    var body: some View {
        let columns = [GridItem(.fixed(520), spacing: 12), GridItem(.fixed(520), spacing: 12), GridItem(.fixed(520))]
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Tutorial.Step.allCases, id: \.self) { step in
                OnboardingView(model: .preview(at: step))
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(12)
    }
}
