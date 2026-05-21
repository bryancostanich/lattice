import AppKit

final class OverviewPanel: NSPanel {
    var onCancel: (() -> Void)?
    var onNumberKey: ((Int) -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers,
              let scalar = chars.unicodeScalars.first,
              let digit = Int(String(scalar)),
              digit >= 1, digit <= 9 else {
            super.keyDown(with: event)
            return
        }
        onNumberKey?(digit)
    }
}

final class OverviewCellButton: NSButton {
    var spaceID: UInt64 = 0
    var isCurrent: Bool = false
    var thumbnail: NSImage?
    var label: String = ""

    override var wantsUpdateLayer: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 14, yRadius: 14)

        if let thumb = thumbnail {
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            thumb.draw(in: bounds)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            NSColor(white: 0.18, alpha: 1.0).setFill()
            path.fill()
        }

        if isCurrent {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 4
        } else {
            NSColor(white: 1.0, alpha: 0.35).setStroke()
            path.lineWidth = 1
        }
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor.white,
            .shadow: {
                let s = NSShadow()
                s.shadowColor = NSColor(white: 0, alpha: 0.6)
                s.shadowOffset = NSSize(width: 0, height: -1)
                s.shadowBlurRadius = 3
                return s
            }(),
        ]
        let str = label as NSString
        let size = str.size(withAttributes: attrs)
        str.draw(at: NSPoint(x: 16, y: bounds.height - size.height - 12), withAttributes: attrs)
    }
}

final class OverviewWindow {
    private let panel: OverviewPanel
    private let connection: CGSConnectionID = CGSMainConnectionID()
    private var onSelect: ((UInt64) -> Void)?
    private var orderedSpaceIDs: [UInt64] = []

    init() {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let p = OverviewPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .screenSaver
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = false
        p.sharingType = .none
        self.panel = p
        p.onCancel = { [weak self] in self?.hide() }
        p.onNumberKey = { [weak self] n in self?.selectByNumber(n) }
    }

    private func selectByNumber(_ n: Int) {
        let idx = n - 1
        guard idx < orderedSpaceIDs.count else { return }
        let id = orderedSpaceIDs[idx]
        hide()
        onSelect?(id)
    }

    var allowsScreenshot: Bool {
        get { panel.sharingType == .readOnly }
        set { panel.sharingType = newValue ? .readOnly : .none }
    }

    func pinToAllSpaces(_ allSpaceIDs: [UInt64]) {
        guard panel.isVisible, !allSpaceIDs.isEmpty else { return }
        let windowID = NSNumber(value: UInt32(panel.windowNumber))
        let windowsArr = [windowID] as CFArray
        let spacesArr = allSpaceIDs.map { NSNumber(value: $0) } as CFArray
        CGSAddWindowsToSpaces(connection, windowsArr, spacesArr)
        Log.log("overview pinned to \(allSpaceIDs.count) spaces window=\(panel.windowNumber)")
    }

    var isVisible: Bool { panel.isVisible }

    var windowID: CGWindowID? {
        panel.isVisible ? CGWindowID(panel.windowNumber) : nil
    }

    func updateCurrentSpace(_ spaceID: UInt64) {
        guard let content = panel.contentView else { return }
        for sub in content.subviews {
            guard let btn = sub as? OverviewCellButton else { continue }
            let nowCurrent = (btn.spaceID == spaceID)
            if btn.isCurrent != nowCurrent {
                btn.isCurrent = nowCurrent
                btn.needsDisplay = true
            }
        }
    }

    private let cellW: CGFloat = 160
    private let cellH: CGFloat = 100
    private let cellGap: CGFloat = 10
    private let padding: CGFloat = 14
    private let cornerRadius: CGFloat = 14

    func show(
        grid: GridLayout,
        spaceIDs: [UInt64],
        currentSpaceID: UInt64,
        thumbs: ThumbnailCache,
        onScreen: NSScreen,
        onSelect: @escaping (UInt64) -> Void
    ) {
        self.onSelect = onSelect
        self.orderedSpaceIDs = spaceIDs

        let panelW = CGFloat(grid.cols) * cellW + CGFloat(grid.cols - 1) * cellGap + 2 * padding
        let panelH = CGFloat(grid.rows) * cellH + CGFloat(grid.rows - 1) * cellGap + 2 * padding

        let screenFrame = onScreen.frame
        let originX = screenFrame.midX - panelW / 2
        let originY = screenFrame.midY - panelH / 2
        panel.setFrame(NSRect(x: originX, y: originY, width: panelW, height: panelH), display: false)

        let bg = NSVisualEffectView(frame: NSRect(origin: .zero, size: NSSize(width: panelW, height: panelH)))
        bg.material = .hudWindow
        bg.blendingMode = .behindWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = cornerRadius
        bg.layer?.masksToBounds = true

        for r in 0..<grid.rows {
            for c in 0..<grid.cols {
                let idx = r * grid.cols + c
                guard idx < spaceIDs.count else { continue }
                let spaceID = spaceIDs[idx]

                let cellX = padding + CGFloat(c) * (cellW + cellGap)
                let cellY = padding + CGFloat(grid.rows - 1 - r) * (cellH + cellGap)
                let cellFrame = NSRect(x: cellX, y: cellY, width: cellW, height: cellH)

                let btn = OverviewCellButton(frame: cellFrame)
                btn.title = ""
                btn.bezelStyle = .regularSquare
                btn.isBordered = false
                btn.spaceID = spaceID
                btn.isCurrent = (spaceID == currentSpaceID)
                btn.thumbnail = thumbs.image(for: spaceID)
                btn.label = "\(idx + 1)"
                btn.target = self
                btn.action = #selector(cellClicked(_:))
                bg.addSubview(btn)
            }
        }

        panel.contentView = bg
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel.orderOut(nil)
    }

    @objc private func cellClicked(_ sender: OverviewCellButton) {
        let id = sender.spaceID
        hide()
        onSelect?(id)
    }
}
