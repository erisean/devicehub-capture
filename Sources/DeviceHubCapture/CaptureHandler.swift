import Foundation

enum HandlerResult {
    /// Later handlers still get the capture.
    case passThrough
    /// The handler took ownership (e.g. deleted the file); stop the pipeline.
    case consumed
}

/// One thing to do with a Device Hub capture. Add a conformer and list it in `Handlers.all`
/// to get a menu toggle for it.
protocol CaptureHandler {
    var id: String { get }
    var title: String { get }
    var kinds: Set<CaptureKind> { get }
    var enabledByDefault: Bool { get }

    func handle(_ capture: Capture) async throws -> HandlerResult
}

enum Handlers {
    /// Run in order; the first handler to return `.consumed` ends the pipeline.
    static let all: [any CaptureHandler] = [
        CopyScreenshotToPasteboard(),
        ConvertRecordingToGIF(),
    ]
}
