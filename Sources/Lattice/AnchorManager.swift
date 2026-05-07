import AppKit
import ApplicationServices

final class AnchorManager {
    private var anchors: [UInt64: NSWindow] = [:]
    private let connection: CGSConnectionID = CGSMainConnectionID()

    func sync(spaceIDs: [UInt64]) {
        let active = Set(spaceIDs)
        for id in Array(anchors.keys) where !active.contains(id) {
            anchors[id]?.close()
            anchors.removeValue(forKey: id)
        }
        for id in spaceIDs where anchors[id] == nil {
            anchors[id] = makeAnchor(spaceID: id)
        }
    }

    func focus(spaceID: UInt64) {
        guard let win = anchors[spaceID] else {
            Log.log("focus: no anchor for space=\(spaceID)")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        Log.log("focus: makeKeyAndOrderFront space=\(spaceID) windowNumber=\(win.windowNumber)")
    }

    private func makeAnchor(spaceID: UInt64) -> NSWindow {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = .normal
        win.collectionBehavior = []
        win.ignoresMouseEvents = true
        win.isReleasedWhenClosed = false
        win.alphaValue = 0.01
        win.title = "lattice-anchor-\(spaceID)"
        win.orderFront(nil)

        let windowID = NSNumber(value: UInt32(win.windowNumber))
        let arr = [windowID] as CFArray
        CGSMoveWindowsToManagedSpace(connection, arr, spaceID)

        let actualSpaces = (CGSCopySpacesForWindows(connection, kCGSSpaceMaskAll, arr) as? [NSNumber])?.map { $0.uint64Value } ?? []
        Log.log("anchor created space=\(spaceID) windowNumber=\(win.windowNumber) actualSpaces=\(actualSpaces)")
        return win
    }
}
