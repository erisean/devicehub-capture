import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: "enabled")
            isEnabled ? watcher?.start() : watcher?.stop()
        }
    }
    @Published private(set) var enabledHandlerIDs: Set<String>
    @Published private(set) var lastEvent: String?

    private let defaults = UserDefaults.standard
    private var watcher: CaptureWatcher?

    init() {
        isEnabled = defaults.object(forKey: "enabled") as? Bool ?? true
        let defaultIDs = Handlers.all.filter(\.enabledByDefault).map(\.id)
        enabledHandlerIDs = Set(defaults.stringArray(forKey: "enabledHandlers") ?? defaultIDs)

        watcher = CaptureWatcher(directories: CaptureLocations.directories()) { [weak self] capture in
            Task { @MainActor in await self?.process(capture) }
        }
        if isEnabled { watcher?.start() }
    }

    func isHandlerEnabled(_ handler: any CaptureHandler) -> Binding<Bool> {
        Binding(
            get: { self.enabledHandlerIDs.contains(handler.id) },
            set: { on in
                if on { self.enabledHandlerIDs.insert(handler.id) } else { self.enabledHandlerIDs.remove(handler.id) }
                self.defaults.set(Array(self.enabledHandlerIDs), forKey: "enabledHandlers")
            }
        )
    }

    var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { on in
                do {
                    on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister()
                } catch {
                    self.lastEvent = "Launch at login failed: \(error.localizedDescription)"
                }
                self.objectWillChange.send()
            }
        )
    }

    private func process(_ capture: Capture) async {
        guard isEnabled else { return }
        let handlers = Handlers.all.filter { enabledHandlerIDs.contains($0.id) && $0.kinds.contains(capture.kind) }
        for handler in handlers {
            do {
                let result = try await handler.handle(capture)
                lastEvent = "\(handler.title): \(capture.url.lastPathComponent)"
                if case .consumed = result { return }
            } catch {
                lastEvent = "\(handler.title) failed: \(error.localizedDescription)"
                return
            }
        }
    }
}
