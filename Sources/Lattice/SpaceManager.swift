import Foundation
import Carbon
import CoreGraphics

struct SpaceInfo {
    let id: UInt64
    let uuid: String
}

struct DisplayInfo {
    let uuid: String
    let currentSpaceID: UInt64
    let spaces: [SpaceInfo]
}

final class SpaceManager {
    private let connection: CGSConnectionID = CGSMainConnectionID()

    func displays() -> [DisplayInfo] {
        guard let raw = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap { dict in
            guard let rawIdentifier = dict["Display Identifier"] as? String,
                  let spacesRaw = dict["Spaces"] as? [[String: Any]] else { return nil }

            // CGS sometimes returns the literal string "Main" instead of the
            // real display UUID for the primary display. Normalize it so
            // downstream lookups against CGDisplayCreateUUIDFromDisplayID match.
            let uuid: String
            if rawIdentifier == "Main", let mainUUID = SpaceManager.mainDisplayUUID() {
                uuid = mainUUID
            } else {
                uuid = rawIdentifier
            }

            let spaces: [SpaceInfo] = spacesRaw.compactMap { sp in
                let n = (sp["ManagedSpaceID"] as? NSNumber) ?? (sp["id64"] as? NSNumber)
                guard let id = n?.uint64Value else { return nil }
                return SpaceInfo(id: id, uuid: sp["uuid"] as? String ?? "")
            }

            let current: UInt64
            if let cur = dict["Current Space"] as? [String: Any],
               let n = (cur["ManagedSpaceID"] as? NSNumber) ?? (cur["id64"] as? NSNumber) {
                current = n.uint64Value
            } else {
                // The CGS read-back call still uses the raw identifier that CGS gave us.
                current = CGSManagedDisplayGetCurrentSpace(connection, rawIdentifier as CFString)
            }

            return DisplayInfo(uuid: uuid, currentSpaceID: current, spaces: spaces)
        }
    }

    private static func mainDisplayUUID() -> String? {
        let mainID = CGMainDisplayID()
        guard let ref = CGDisplayCreateUUIDFromDisplayID(mainID)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, ref) as String?
    }

    func focus(spaceID: UInt64, on displayUUID: String) {
        CGSManagedDisplaySetCurrentSpace(connection, displayUUID as CFString, spaceID)
    }

    func walkLinear(steps: Int) {
        if steps == 0 { return }
        let key = CGKeyCode(steps > 0 ? kVK_RightArrow : kVK_LeftArrow)
        let count = abs(steps)
        for i in 0..<count {
            let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
            down?.flags = .maskControl
            down?.post(tap: .cghidEventTap)
            let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
            up?.flags = .maskControl
            up?.post(tap: .cghidEventTap)
            if i < count - 1 {
                Thread.sleep(forTimeInterval: 0.06)
            }
        }
    }
}
