import AppKit
import ScreenCaptureKit

final class ThumbnailCache {
    private var cache: [UInt64: NSImage] = [:]

    func image(for spaceID: UInt64) -> NSImage? {
        cache[spaceID]
    }

    func capture(spaceID: UInt64, screen: NSScreen) {
        Task { await captureAsync(spaceID: spaceID, screen: screen) }
    }

    private func captureAsync(spaceID: UInt64, screen: NSScreen) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let displayID = await MainActor.run(body: { screen.displayID }),
                  let display = content.displays.first(where: { $0.displayID == displayID }) else {
                Log.log("SCK: no display match for space=\(spaceID)")
                return
            }

            let myPID = ProcessInfo.processInfo.processIdentifier
            let excludeApps = content.applications.filter { $0.processID == myPID }
            let filter = SCContentFilter(
                display: display,
                excludingApplications: excludeApps,
                exceptingWindows: []
            )

            let cfg = SCStreamConfiguration()
            let scale = await MainActor.run { screen.backingScaleFactor }
            cfg.width = Int(display.width)
            cfg.height = Int(display.height)
            cfg.scalesToFit = false
            cfg.showsCursor = false
            _ = scale

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: cfg
            )

            await MainActor.run {
                let img = NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                )
                self.cache[spaceID] = img
                Log.log("SCK captured space=\(spaceID) size=\(cgImage.width)x\(cgImage.height)")
            }
        } catch {
            Log.log("SCK capture failed for space=\(spaceID): \(error)")
        }
    }
}
