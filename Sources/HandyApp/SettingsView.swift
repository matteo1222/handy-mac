import HandyCore
import HandyOutput
import HandyPerception
import SwiftUI

/// Handy's settings window. Sections are added as features land.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        Form {
            GeneralSection()
            PresetSection(model: model)
            SensitivitySection(model: model)
            PaletteEditor(model: model)
            CameraSection(model: model)
            DictationSection()
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct CameraSection: View {
    let model: AppModel
    @State private var devices: [CameraDevice] = []

    var body: some View {
        Section {
            Picker("Camera", selection: selection) {
                Text("System default").tag(String?.none)
                ForEach(devices) { device in
                    Label(device.name, systemImage: device.kind.symbol).tag(Optional(device.id))
                }
            }
            if let missing = missingSelection {
                Text("\(missing) is not connected; Handy will use the system default.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Camera")
        } footer: {
            Text("Use an external webcam or an iPhone (Continuity Camera) when the Mac sits far away.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .task { devices = CameraDevices.available() }
    }

    private var selection: Binding<String?> {
        Binding(get: { model.cameraID }, set: { model.cameraID = $0 })
    }

    private var missingSelection: String? {
        guard let id = model.cameraID, !devices.contains(where: { $0.id == id }) else { return nil }
        return "The chosen camera"
    }
}

extension CameraDevice.Kind {
    var symbol: String {
        switch self {
        case .builtIn: "laptopcomputer"
        case .external: "web.camera"
        case .continuity: "iphone"
        }
    }
}

struct DictationSection: View {
    @State private var shortcut = DictationShortcut.current()

    var body: some View {
        Section {
            LabeledContent("Shaka (🤙) toggles Dictation") {
                if let shortcut {
                    Text(shortcut.description).foregroundStyle(.secondary)
                } else {
                    Button("Set Up in Keyboard Settings") {
                        if let url = DictationShortcut.settingsURL { NSWorkspace.shared.open(url) }
                    }
                }
            }
        } header: {
            Text("Dictation")
        } footer: {
            Text(
                shortcut == nil
                    ? "Turn on Dictation and choose a shortcut in System Settings → Keyboard; Handy sends that shortcut."
                    : "Handy sends your Dictation shortcut."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .onAppear { shortcut = DictationShortcut.current() }
    }
}

struct PresetSection: View {
    let model: AppModel

    var body: some View {
        Section {
            Picker("Preset", selection: Binding(get: { model.settings.preset }, set: { model.settings.preset = $0 })) {
                ForEach(Preset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Where you sit")
        } footer: {
            Text(model.settings.preset.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct SensitivitySection: View {
    let model: AppModel

    var body: some View {
        Section {
            ForEach(SensitivityKey.allCases, id: \.self) { key in
                SensitivityRow(
                    key: key, value: Binding(get: { model.settings[key] }, set: { model.settings[key] = $0 }),
                    meter: model.meters[key] ?? 0)
            }
        } header: {
            Text("Sensitivity")
        } footer: {
            Text("The bar shows your hand live; it fills at the point where the gesture triggers.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .onAppear { model.metersVisible = true }
        .onDisappear { model.metersVisible = false }
    }
}

struct SensitivityRow: View {
    let key: SensitivityKey
    @Binding var value: Double
    let meter: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(key.title)
                Spacer()
                Text(label).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $value, in: 0...1) {
                Text(key.title)
            } minimumValueLabel: {
                Image(systemName: "tortoise").accessibilityLabel("Less sensitive")
            } maximumValueLabel: {
                Image(systemName: "hare").accessibilityLabel("More sensitive")
            }
            .labelsHidden()
            Gauge(value: meter) { Text("Live") }
                .gaugeStyle(.accessoryLinearCapacity)
                .labelsHidden()
                .tint(meter >= 1 ? .green : .accentColor)
                .accessibilityLabel("\(key.title) live level")
                .accessibilityValue(meter >= 1 ? "Triggering" : "\(Int(meter * 100)) percent")
        }
    }

    private var label: String {
        switch value {
        case ..<0.35: "Less sensitive"
        case 0.65...: "More sensitive"
        default: "Default"
        }
    }
}

extension Preset {
    var explanation: String {
        switch self {
        case .desk: "About arm's length from the built-in camera."
        case .couch: "1.5 to 3 m away, with an external webcam or Continuity Camera."
        case .presenter: "Steadier pointer and more deliberate engage and keys, for slides and demos."
        }
    }
}

/// Palette slots for every app, or for the app that was frontmost when Settings opened.
struct PaletteEditor: View {
    let model: AppModel
    @State private var appID: String?
    @State private var appName: String?

    nonisolated static let options = NamedAction.allCases

    var body: some View {
        Section {
            Picker("Applies to", selection: $appID) {
                Text("All apps").tag(String?.none)
                if let frontmost = Self.frontmostApp() {
                    Text(frontmost.name).tag(Optional(frontmost.id))
                }
                ForEach(
                    model.settings.palette.perApp.keys.sorted().filter { $0 != Self.frontmostApp()?.id }, id: \.self
                ) {
                    Text($0).tag(Optional($0))
                }
            }
            ForEach(0..<PaletteLayout.slotCount, id: \.self) { slot in
                Picker(Self.slotName(slot), selection: binding(for: slot)) {
                    Text("Empty").tag(NamedAction?.none)
                    ForEach(Self.options, id: \.self) { action in
                        Label(action.title, systemImage: action.symbol).tag(Optional(action))
                    }
                }
            }
            if appID != nil {
                Button("Use the All Apps Layout Here") {
                    if let appID { model.settings.palette.perApp[appID] = nil }
                }
            }
        } header: {
            Text("Command palette")
        } footer: {
            Text("While engaged, pinch and hold with your other hand, then move toward a slot.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func binding(for slot: Int) -> Binding<NamedAction?> {
        Binding(
            get: { model.settings.palette.layout(for: appID).slots[slot] },
            set: { action in
                var layout = model.settings.palette.layout(for: appID)
                layout.slots[slot] = action
                if let appID {
                    model.settings.palette.perApp[appID] = layout
                } else {
                    model.settings.palette.standard = layout
                }
            })
    }

    static func slotName(_ slot: Int) -> String {
        ["Up", "Up right", "Right", "Down right", "Down", "Down left", "Left", "Up left"][slot]
    }

    /// The app that was in front before Handy, skipping Handy itself.
    static func frontmostApp() -> (id: String, name: String)? {
        let app =
            NSWorkspace.shared.runningApplications.first {
                $0.isActive == false && $0.activationPolicy == .regular
                    && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                    && $0.ownsMenuBar
            } ?? NSWorkspace.shared.frontmostApplication
        guard let app, let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
        return (id, app.localizedName ?? id)
    }
}

struct GeneralSection: View {
    @State private var openAtLogin = LaunchAtLogin.isEnabled
    @State private var error: String?

    var body: some View {
        Section {
            Toggle("Open Handy at login", isOn: $openAtLogin)
                .onChange(of: openAtLogin) { _, enabled in
                    do {
                        try LaunchAtLogin.set(enabled)
                        error = nil
                    } catch {
                        self.error = error.localizedDescription
                        openAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
            }
        } header: {
            Text("General")
        }
    }
}
