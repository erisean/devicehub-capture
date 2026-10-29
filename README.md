# DeviceHub Capture

Menu bar app that picks up screenshots and screen recordings saved by Xcode's Device Hub and does something with them.

- Screenshots → copied to the clipboard, file deleted.
- Recordings → converted to a GIF (12 fps, max 800px) on the clipboard, `.mp4` deleted. The GIF lives in `~/Library/Caches/DeviceHubCapture/GIFs` (last 10 kept) so apps that need a file URL can paste it.

Device Hub captures are recognized by their `com.apple.quarantine` xattr, whose agent field is `DeviceHub`, so regular macOS screenshots are ignored. Only files that appear after the app starts are processed.

## Build

```sh
./scripts/build-app.sh            # -> build/DeviceHub Capture.app
./scripts/build-app.sh --install  # copy to ~/Applications and launch
```

## Adding an action

1. Add a `CaptureHandler` conformer in `Sources/DeviceHubCapture/Handlers/`.
2. Add it to `Handlers.all` in `CaptureHandler.swift`; it gets a menu toggle automatically.

Handlers run in list order for matching `kinds`. Return `.passThrough` to let later handlers see the file, or `.consumed` once you've taken ownership of it (e.g. deleted it).
