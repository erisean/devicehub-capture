import Foundation
import UniformTypeIdentifiers

enum CaptureKind: String, CaseIterable {
    case screenshot
    case recording
}

struct Capture {
    let url: URL
    let kind: CaptureKind

    /// Returns nil unless the file was written by Device Hub and is an image or movie.
    init?(url: URL) {
        guard Capture.quarantineAgent(of: url) == "DeviceHub",
              let type = UTType(filenameExtension: url.pathExtension) else { return nil }
        if type.conforms(to: .image) {
            kind = .screenshot
        } else if type.conforms(to: .movie) {
            kind = .recording
        } else {
            return nil
        }
        self.url = url
    }

    /// The quarantine xattr is "flags;timestamp;agent;uuid"; Device Hub stamps its own name as the agent.
    static func quarantineAgent(of url: URL) -> String? {
        let name = "com.apple.quarantine"
        let size = getxattr(url.path, name, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard getxattr(url.path, name, &buffer, size, 0, 0) == size else { return nil }
        let fields = String(decoding: buffer, as: UTF8.self)
            .split(separator: ";", omittingEmptySubsequences: false)
        return fields.count > 2 ? String(fields[2]) : nil
    }
}

enum CaptureError: LocalizedError {
    case unreadable(URL)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url): "Couldn't read \(url.lastPathComponent)"
        }
    }
}
