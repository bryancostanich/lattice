import AppKit
import ApplicationServices
import Carbon

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var cgFrame: CGRect {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? self
        let primaryMaxY = primary.frame.height
        return CGRect(
            x: frame.origin.x,
            y: primaryMaxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func screen(forDisplayUUID uuid: String) -> NSScreen? {
        for s in NSScreen.screens {
            guard let did = s.displayID,
                  let u = displayUUIDString(for: did) else { continue }
            if u == uuid { return s }
        }
        return nil
    }
}

func displayUUIDString(for displayID: CGDirectDisplayID) -> String? {
    guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
        return nil
    }
    return CFUUIDCreateString(nil, uuidRef) as String?
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let spaceManager = SpaceManager()
    private let anchorManager = AnchorManager()
    private let thumbs = ThumbnailCache()
    private let overview = OverviewWindow()
    private var config: Config = .default
    private var dismissTimer: Timer?
    private let autoDismissAfter: TimeInterval = 1.0
    private let manualDismissAfter: TimeInterval = 3.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.log("launch")

        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        Log.log("accessibility trusted=\(trusted)")

        let screenPreflight = CGPreflightScreenCaptureAccess()
        Log.log("screen capture preflight=\(screenPreflight)")
        if !screenPreflight {
            let requested = CGRequestScreenCaptureAccess()
            Log.log("screen capture access requested=\(requested)")
        }

        config = Config.load()

        let displays = spaceManager.displays()
        Log.log("displays=\(displays.count)")
        for d in displays {
            Log.log("  display uuid=\(d.uuid) currentSpace=\(d.currentSpaceID) spaces=\(d.spaces.count) ids=\(d.spaces.map { $0.id })")
        }
        anchorManager.sync(spaceIDs: displays.flatMap { $0.spaces.map { $0.id } })
        for d in displays {
            if let screen = NSScreen.screen(forDisplayUUID: d.uuid) {
                thumbs.capture(spaceID: d.currentSpaceID, screen: screen)
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        Log.log("statusItem button=\(String(describing: statusItem.button))")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        registerHotkeys()
        updateStatus()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    private func registerHotkeys() {
        let mods = UInt32(controlKey | optionKey)
        let mgr = HotkeyManager.shared
        mgr.register(keyCode: UInt32(kVK_LeftArrow),  modifiers: mods) { [weak self] in Log.log("hotkey left"); self?.move(.left) }
        mgr.register(keyCode: UInt32(kVK_RightArrow), modifiers: mods) { [weak self] in Log.log("hotkey right"); self?.move(.right) }
        mgr.register(keyCode: UInt32(kVK_UpArrow),    modifiers: mods) { [weak self] in Log.log("hotkey up"); self?.move(.up) }
        mgr.register(keyCode: UInt32(kVK_DownArrow),  modifiers: mods) { [weak self] in Log.log("hotkey down"); self?.move(.down) }
        mgr.register(keyCode: UInt32(kVK_Space),      modifiers: mods) { [weak self] in Log.log("hotkey overview"); self?.toggleOverview() }
        Log.log("registered hotkeys ctrl+opt+arrows + ctrl+opt+space")
    }

    private func toggleOverview() {
        if overview.isVisible {
            dismissTimer?.invalidate()
            dismissTimer = nil
            overview.hide()
            return
        }
        showOverview(dismissAfter: manualDismissAfter)
    }

    private func showOverview(dismissAfter: TimeInterval? = nil) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen,
              let displayID = screen.displayID,
              let uuid = displayUUIDString(for: displayID),
              let display = spaceManager.displays().first(where: { $0.uuid == uuid })
        else { return }
        let grid = config.grid(for: uuid, spaceCount: display.spaces.count)
        let spaceIDs = display.spaces.map { $0.id }

        if overview.isVisible {
            overview.updateCurrentSpace(display.currentSpaceID)
        } else {
            overview.show(
                grid: grid,
                spaceIDs: spaceIDs,
                currentSpaceID: display.currentSpaceID,
                thumbs: thumbs,
                onScreen: screen
            ) { [weak self] selectedSpaceID in
                self?.anchorManager.focus(spaceID: selectedSpaceID)
            }
            overview.pinToAllSpaces(spaceIDs)
        }
        resetDismissTimer(interval: dismissAfter ?? autoDismissAfter)
    }

    private func resetDismissTimer(interval: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.overview.hide()
            self?.dismissTimer = nil
        }
    }

    private func move(_ direction: Direction) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main,
              let displayID = screen.displayID,
              let uuid = displayUUIDString(for: displayID)
        else { Log.log("move \(direction): no display"); return }

        guard let display = spaceManager.displays().first(where: { $0.uuid == uuid }),
              let currentIdx = display.spaces.firstIndex(where: { $0.id == display.currentSpaceID })
        else { Log.log("move \(direction): no current space on \(uuid)"); return }

        let grid = config.grid(for: uuid, spaceCount: display.spaces.count)
        guard let targetIdx = grid.target(
            from: currentIdx,
            direction: direction,
            count: display.spaces.count,
            wrap: config.wrap
        ) else {
            Log.log("move \(direction): out of bounds (idx=\(currentIdx) grid=\(grid.cols)x\(grid.rows) count=\(display.spaces.count) wrap=\(config.wrap))")
            return
        }

        let target = display.spaces[targetIdx]
        Log.log("move \(direction): \(currentIdx) -> \(targetIdx) spaceID=\(target.id)")
        anchorManager.focus(spaceID: target.id)
    }

    @objc private func reloadConfig() {
        config = Config.load()
        updateStatus()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let displays = spaceManager.displays()
        if let display = displays.first {
            let grid = config.grid(for: display.uuid, spaceCount: display.spaces.count)
            for (idx, space) in display.spaces.enumerated() {
                let pos = grid.position(for: idx)
                let item = NSMenuItem(
                    title: "Space [\(pos.col + 1),\(pos.row + 1)]",
                    action: #selector(jumpToSpace(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = NSNumber(value: space.id)
                if space.id == display.currentSpaceID {
                    item.state = .on
                }
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let reload = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)

        let allowShot = NSMenuItem(title: "Allow Screenshot of Overview", action: #selector(toggleAllowScreenshot), keyEquivalent: "")
        allowShot.target = self
        allowShot.state = overview.allowsScreenshot ? .on : .off
        menu.addItem(allowShot)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Lattice",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    private func handFocusToTopmostApp() {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            NSApp.deactivate()
            return
        }
        let myPID = ProcessInfo.processInfo.processIdentifier
        for dict in info {
            guard let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = dict[kCGWindowOwnerPID as String] as? Int32,
                  pid != myPID,
                  let app = NSRunningApplication(processIdentifier: pid) else { continue }
            app.activate()
            Log.log("focus handed to pid=\(pid) app=\(app.localizedName ?? "?")")
            return
        }
        Log.log("no app to focus, deactivating Lattice")
        NSApp.deactivate()
    }

    @objc private func toggleAllowScreenshot() {
        overview.allowsScreenshot.toggle()
    }

    @objc private func jumpToSpace(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? NSNumber)?.uint64Value else { return }
        anchorManager.focus(spaceID: id)
    }

    @objc private func spaceChanged() {
        let displays = spaceManager.displays()
        anchorManager.sync(spaceIDs: displays.flatMap { $0.spaces.map { $0.id } })
        updateStatus()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.handFocusToTopmostApp()
        }

        showOverview()

        let captures: [(UInt64, NSScreen)] = displays.compactMap { d in
            guard let screen = NSScreen.screen(forDisplayUUID: d.uuid) else { return nil }
            return (d.currentSpaceID, screen)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            for (id, screen) in captures { self?.thumbs.capture(spaceID: id, screen: screen) }
        }
    }

    private func updateStatus() {
        guard let screen = NSScreen.main,
              let displayID = screen.displayID,
              let uuid = displayUUIDString(for: displayID),
              let display = spaceManager.displays().first(where: { $0.uuid == uuid }),
              let idx = display.spaces.firstIndex(where: { $0.id == display.currentSpaceID })
        else {
            statusItem?.button?.title = "Lattice"
            return
        }
        let grid = config.grid(for: uuid, spaceCount: display.spaces.count)
        let (col, row) = grid.position(for: idx)
        statusItem.button?.title = "[\(col + 1),\(row + 1)]"
    }
}
