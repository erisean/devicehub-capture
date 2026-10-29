import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

struct ConvertRecordingToGIF: CaptureHandler {
    let id = "convert-recording-to-gif"
    let title = "Convert Recordings to GIF on Clipboard"
    let kinds: Set<CaptureKind> = [.recording]
    let enabledByDefault = true

    var framesPerSecond = 12.0
    var maxDimension = 800.0
    /// Pasting an animated GIF into most apps needs a file URL, so recent GIFs are kept here.
    var cacheLimit = 10

    func handle(_ capture: Capture) async throws -> HandlerResult {
        let gifURL = try cacheDirectory()
            .appending(path: capture.url.deletingPathExtension().lastPathComponent + ".gif")
        try await writeGIF(from: capture.url, to: gifURL)
        let gifData = try Data(contentsOf: gifURL)

        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            item.setString(gifURL.absoluteString, forType: .fileURL)
            item.setData(gifData, forType: NSPasteboard.PasteboardType(UTType.gif.identifier))
            pasteboard.writeObjects([item])
        }

        try FileManager.default.removeItem(at: capture.url)
        pruneCache(keeping: gifURL)
        return .consumed
    }

    private func writeGIF(from movie: URL, to destinationURL: URL) async throws {
        let asset = AVURLAsset(url: movie)
        let duration = try await asset.load(.duration).seconds
        let frameCount = max(1, Int(duration * framesPerSecond))
        let delay = 1.0 / framesPerSecond

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        let tolerance = CMTime(seconds: delay / 2, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil
        ) else { throw CaptureError.unreadable(movie) }

        CGImageDestinationSetProperties(destination, [
            kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
        ] as CFDictionary)
        let frameProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay,
                kCGImagePropertyGIFUnclampedDelayTime: delay,
            ],
        ] as CFDictionary

        let times = (0..<frameCount).map { CMTime(seconds: Double($0) * delay, preferredTimescale: 600) }
        for await result in generator.images(for: times) {
            if let image = try? result.image {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }
        guard CGImageDestinationFinalize(destination) else { throw CaptureError.unreadable(movie) }
    }

    private func cacheDirectory() throws -> URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "DeviceHubCapture/GIFs", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func pruneCache(keeping current: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: current.deletingLastPathComponent(), includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let date = { (url: URL) in
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        }
        files.sorted { date($0) > date($1) }
            .dropFirst(cacheLimit)
            .filter { $0 != current }
            .forEach { try? fm.removeItem(at: $0) }
    }
}
