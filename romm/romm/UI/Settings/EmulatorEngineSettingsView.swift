import SwiftUI

struct EmulatorEngineSettingsView: View {
    @State private var selection: EmulatorEngine
    private let preference: PEmulatorEnginePreference

    init(factory: PDependencyFactory = DefaultDependencyFactory.shared) {
        self.preference = factory.enginePreference
        _selection = State(wrappedValue: factory.enginePreference.current)
    }

    var body: some View {
        Form {
            Section(header: Text("Engine")) {
                Picker("Engine", selection: $selection) {
                    Text("Web (EmulatorJS)").tag(EmulatorEngine.web)
                    Text("Native (DeltaCore, etc.)").tag(EmulatorEngine.native)
                }
                .pickerStyle(.inline)
            }
            Section(footer: Text("Native runs emulation on-device via embedded cores (DeltaCore for Game Boy / Color, GBA, NES, SNES, N64, Nintendo DS, Sega Genesis; libretro for PlayStation). Other platforms fall back to Web automatically.")) { EmptyView() }
        }
        .navigationTitle("Emulator")
        .onChange(of: selection) { _, new in preference.current = new }
    }
}
