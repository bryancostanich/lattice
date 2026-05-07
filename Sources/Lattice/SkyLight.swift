import Foundation
import CoreGraphics

typealias CGSConnectionID = Int32

private let skyLightHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
    RTLD_LAZY
)

private func sym(_ name: String) -> UnsafeMutableRawPointer? {
    dlsym(skyLightHandle, name)
}

private typealias FnMainConnectionID = @convention(c) () -> CGSConnectionID
private typealias FnCopyManagedDisplaySpaces = @convention(c) (CGSConnectionID) -> CFArray?
private typealias FnSetCurrentSpace = @convention(c) (CGSConnectionID, CFString, UInt64) -> Void
private typealias FnGetCurrentSpace = @convention(c) (CGSConnectionID, CFString) -> UInt64
private typealias FnMoveWindowsToManagedSpace = @convention(c) (CGSConnectionID, CFArray, UInt64) -> Void
private typealias FnCopySpacesForWindows = @convention(c) (CGSConnectionID, Int32, CFArray) -> CFArray?
private typealias FnAddWindowsToSpaces = @convention(c) (CGSConnectionID, CFArray, CFArray) -> Void
private typealias FnRemoveWindowsFromSpaces = @convention(c) (CGSConnectionID, CFArray, CFArray) -> Void

private let _mainConnection: FnMainConnectionID? =
    sym("CGSMainConnectionID").map { unsafeBitCast($0, to: FnMainConnectionID.self) }
private let _copyManagedDisplaySpaces: FnCopyManagedDisplaySpaces? =
    sym("CGSCopyManagedDisplaySpaces").map { unsafeBitCast($0, to: FnCopyManagedDisplaySpaces.self) }
private let _setCurrentSpace: FnSetCurrentSpace? =
    sym("CGSManagedDisplaySetCurrentSpace").map { unsafeBitCast($0, to: FnSetCurrentSpace.self) }
private let _getCurrentSpace: FnGetCurrentSpace? =
    sym("CGSManagedDisplayGetCurrentSpace").map { unsafeBitCast($0, to: FnGetCurrentSpace.self) }
private let _moveWindowsToManagedSpace: FnMoveWindowsToManagedSpace? =
    sym("CGSMoveWindowsToManagedSpace").map { unsafeBitCast($0, to: FnMoveWindowsToManagedSpace.self) }
private let _copySpacesForWindows: FnCopySpacesForWindows? =
    sym("CGSCopySpacesForWindows").map { unsafeBitCast($0, to: FnCopySpacesForWindows.self) }
private let _addWindowsToSpaces: FnAddWindowsToSpaces? =
    sym("CGSAddWindowsToSpaces").map { unsafeBitCast($0, to: FnAddWindowsToSpaces.self) }
private let _removeWindowsFromSpaces: FnRemoveWindowsFromSpaces? =
    sym("CGSRemoveWindowsFromSpaces").map { unsafeBitCast($0, to: FnRemoveWindowsFromSpaces.self) }

func CGSMainConnectionID() -> CGSConnectionID {
    _mainConnection?() ?? 0
}

func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray? {
    _copyManagedDisplaySpaces?(cid)
}

func CGSManagedDisplaySetCurrentSpace(_ cid: CGSConnectionID, _ display: CFString, _ space: UInt64) {
    _setCurrentSpace?(cid, display, space)
}

func CGSManagedDisplayGetCurrentSpace(_ cid: CGSConnectionID, _ display: CFString) -> UInt64 {
    _getCurrentSpace?(cid, display) ?? 0
}

func CGSMoveWindowsToManagedSpace(_ cid: CGSConnectionID, _ windows: CFArray, _ space: UInt64) {
    _moveWindowsToManagedSpace?(cid, windows, space)
}

let kCGSSpaceMaskAll: Int32 = 7

func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int32, _ windows: CFArray) -> CFArray? {
    _copySpacesForWindows?(cid, mask, windows)
}

func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray) {
    _addWindowsToSpaces?(cid, windows, spaces)
}

func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray) {
    _removeWindowsFromSpaces?(cid, windows, spaces)
}
