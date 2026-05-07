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
            guard let uuid = dict["Display Identifier"] as? String,
                  let spacesRaw = dict["Spaces"] as? [[String: Any]] else { return nil }

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
                current = CGSManagedDisplayGetCurrentSpace(connection, uuid as CFString)
            }

            return DisplayInfo(uuid: uuid, currentSpaceID: current, spaces: spaces)
        }
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
