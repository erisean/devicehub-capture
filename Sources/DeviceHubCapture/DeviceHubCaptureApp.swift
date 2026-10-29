import SwiftUI

@main
struct DeviceHubCaptureApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: state.isEnabled ? "iphone" : "iphone.slash")
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var state: AppState

    var body: some View {
        Toggle("Watch Device Hub", isOn: $state.isEnabled)

        Section("Actions") {
            ForEach(Handlers.all, id: \.id) { handler in
                Toggle(handler.title, isOn: state.isHandlerEnabled(handler))
            }
        }
        .disabled(!state.isEnabled)

        if let lastEvent = state.lastEvent {
            Divider()
            Text(lastEvent)
        }

        Divider()
        Toggle("Launch at Login", isOn: state.launchAtLogin)
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
