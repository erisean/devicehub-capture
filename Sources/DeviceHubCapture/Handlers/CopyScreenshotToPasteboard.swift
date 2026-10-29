import AppKit

struct CopyScreenshotToPasteboard: CaptureHandler {
    let id = "copy-screenshot-to-pasteboard"
    let title = "Move Screenshots to Clipboard"
    let kinds: Set<CaptureKind> = [.screenshot]
    let enabledByDefault = true

    func handle(_ capture: Capture) async throws -> HandlerResult {
        let data = try Data(contentsOf: capture.url)
        guard let image = NSImage(data: data), let tiff = image.tiffRepresentation else {
            throw CaptureError.unreadable(capture.url)
        }
        let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])

        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            if let png { item.setData(png, forType: .png) }
            item.setData(tiff, forType: .tiff)
            pasteboard.writeObjects([item])
        }

        try FileManager.default.removeItem(at: capture.url)
        return .consumed
    }
}
