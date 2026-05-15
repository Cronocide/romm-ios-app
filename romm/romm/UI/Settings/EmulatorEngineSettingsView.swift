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
                    Text("DeltaCore (Beta)").tag(EmulatorEngine.deltaCore)
                }
                .pickerStyle(.inline)
            }
            Section(footer: Text("DeltaCore startet die Emulation nativ. Aktuell wird nur Game Boy Advance unterstützt; andere Plattformen fallen automatisch auf Web zurück.")) { EmptyView() }
        }
        .navigationTitle("Emulator")
        .onChange(of: selection) { _, new in preference.current = new }
    }
}
