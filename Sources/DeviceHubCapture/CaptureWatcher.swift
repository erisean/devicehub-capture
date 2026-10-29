import Foundation

/// Watches directories for files that appear after `start()` and reports the ones Device Hub wrote.
final class CaptureWatcher {
    private let directories: [URL]
    private let onCapture: (Capture) -> Void
    private let queue = DispatchQueue(label: "DeviceHubCapture.watcher")
    private var sources: [DispatchSourceFileSystemObject] = []
    private var known: Set<URL> = []

    init(directories: [URL], onCapture: @escaping (Capture) -> Void) {
        self.directories = directories
        self.onCapture = onCapture
    }

    deinit { stop() }

    func start() {
        stop()
        queue.sync { known = currentFiles() }
        for directory in directories {
            let fd = open(directory.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: queue)
            source.setEventHandler { [weak self] in self?.scan() }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources = []
    }

    private func scan() {
        let current = currentFiles()
        let added = current.subtracting(known)
        known = current
        for url in added {
            if let capture = Capture(url: url) { onCapture(capture) }
        }
    }

    private func currentFiles() -> Set<URL> {
        let fm = FileManager.default
        return Set(directories.flatMap {
            (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        })
    }
}

enum CaptureLocations {
    /// The Desktop, plus Device Hub's custom save location if one is configured.
    static func directories() -> [URL] {
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop", directoryHint: .isDirectory)
        guard let custom = configuredSaveLocation(), custom.standardizedFileURL != desktop.standardizedFileURL else {
            return [desktop]
        }
        return [desktop, custom]
    }

    private static func configuredSaveLocation() -> URL? {
        let value = UserDefaults(suiteName: "com.apple.dt.Devices")?.object(forKey: "ScreenShotSaveLocation")
        if let path = value as? String { return url(from: path) }
        guard let data = value as? Data else { return nil }
        if let path = try? JSONDecoder().decode(String.self, from: data) { return url(from: path) }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: .withoutUI, bookmarkDataIsStale: &stale)
    }

    private static func url(from string: String) -> URL? {
        if let url = URL(string: string), url.isFileURL { return url }
        let path = (string as NSString).expandingTildeInPath
        return path.hasPrefix("/") ? URL(filePath: path, directoryHint: .isDirectory) : nil
    }
}
