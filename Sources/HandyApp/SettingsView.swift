import HandyPerception
import SwiftUI

/// Handy's settings window. Sections are added as features land.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        Form {
            CameraSection(model: model)
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
