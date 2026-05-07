import AppKit
import CoreGraphics

final class ThumbnailCache {
    private var cache: [UInt64: NSImage] = [:]

    func capture(spaceID: UInt64) {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            [.optionOnScreenOnly],
            kCGNullWindowID,
            [.nominalResolution]
        ) else {
            Log.log("thumbnail capture failed for space=\(spaceID)")
            return
        }
        let img = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        cache[spaceID] = img
        Log.log("thumbnail captured space=\(spaceID) size=\(cgImage.width)x\(cgImage.height)")
    }

    func image(for spaceID: UInt64) -> NSImage? {
        cache[spaceID]
    }
}
