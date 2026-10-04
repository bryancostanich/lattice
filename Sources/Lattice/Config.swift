import Carbon
import Foundation

/// Global hotkeys. `modifiers` apply to the four arrow keys and to the overview key.
struct HotkeyConfig: Codable, Equatable {
    var modifiers: [String]
    var overview: String

    static let `default` = HotkeyConfig(modifiers: ["ctrl", "opt"], overview: "space")

    init(modifiers: [String], overview: String) {
        self.modifiers = modifiers
        self.overview = overview
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modifiers = try c.decodeIfPresent([String].self, forKey: .modifiers) ?? Self.default.modifiers
        overview = try c.decodeIfPresent(String.self, forKey: .overview) ?? Self.default.overview
    }

    /// Carbon modifier mask for `RegisterEventHotKey`, or nil if a name is unknown or the list is empty.
    var carbonModifiers: UInt32? {
        var mask = 0
        for name in modifiers {
            switch name.lowercased() {
            case "ctrl", "control": mask |= controlKey
            case "opt", "option", "alt": mask |= optionKey
            case "cmd", "command": mask |= cmdKey
            case "shift": mask |= shiftKey
            default: return nil
            }
        }
        return mask == 0 ? nil : UInt32(mask)
    }

    /// The same modifiers as CoreGraphics event flags (used by the diagnostic event tap).
    var eventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for name in modifiers {
            switch name.lowercased() {
            case "ctrl", "control": flags.insert(.maskControl)
            case "opt", "option", "alt": flags.insert(.maskAlternate)
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            default: break
            }
        }
        return flags
    }

    /// Virtual key code for the overview key, or nil if the name is unknown.
    var overviewKeyCode: UInt32? {
        Self.keyCodes[overview.lowercased()].map(UInt32.init)
    }

    /// Human-readable form for logs, e.g. "ctrl+cmd".
    var modifiersDescription: String {
        modifiers.map { $0.lowercased() }.joined(separator: "+")
    }

    private static let keyCodes: [String: Int] = [
        "space": kVK_Space, "return": kVK_Return, "enter": kVK_Return, "tab": kVK_Tab,
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
        "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
        "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
        "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y,
        "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
        "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    ]
}

/// What each overview tile shows.
enum OverviewTiles: String, Codable {
    /// A screenshot of the space with its number in the corner (needs Screen Recording).
    case preview
    /// Only the space number, large and centred, on a compact tile.
    case number
}

struct OverviewConfig: Codable, Equatable {
    var tiles: OverviewTiles
    /// Seconds the overview stays up after a space switch. 0 disables the pop-up.
    var hideAfterSwitch: TimeInterval
    /// Seconds the overview stays up after being opened with its hotkey.
    var hideAfterOpen: TimeInterval

    static let `default` = OverviewConfig(tiles: .preview, hideAfterSwitch: 1.0, hideAfterOpen: 3.0)

    init(tiles: OverviewTiles, hideAfterSwitch: TimeInterval, hideAfterOpen: TimeInterval) {
        self.tiles = tiles
        self.hideAfterSwitch = hideAfterSwitch
        self.hideAfterOpen = hideAfterOpen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tiles = try c.decodeIfPresent(OverviewTiles.self, forKey: .tiles) ?? Self.default.tiles
        hideAfterSwitch = try c.decodeIfPresent(TimeInterval.self, forKey: .hideAfterSwitch) ?? Self.default.hideAfterSwitch
        hideAfterOpen = try c.decodeIfPresent(TimeInterval.self, forKey: .hideAfterOpen) ?? Self.default.hideAfterOpen
    }
}

struct Config: Codable {
    var displays: [String: GridLayout]
    var defaultGrid: GridLayout?
    var wrap: Bool
    var hotkeys: HotkeyConfig
    var overview: OverviewConfig

    static let `default` = Config(
        displays: [:], defaultGrid: nil, wrap: true, hotkeys: .default, overview: .default
    )

    init(
        displays: [String: GridLayout],
        defaultGrid: GridLayout?,
        wrap: Bool,
        hotkeys: HotkeyConfig,
        overview: OverviewConfig
    ) {
        self.displays = displays
        self.defaultGrid = defaultGrid
        self.wrap = wrap
        self.hotkeys = hotkeys
        self.overview = overview
    }

    /// Every key is optional, so a config file only needs the settings it changes.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displays = try c.decodeIfPresent([String: GridLayout].self, forKey: .displays) ?? [:]
        defaultGrid = try c.decodeIfPresent(GridLayout.self, forKey: .defaultGrid)
        wrap = try c.decodeIfPresent(Bool.self, forKey: .wrap) ?? false
        hotkeys = try c.decodeIfPresent(HotkeyConfig.self, forKey: .hotkeys) ?? .default
        overview = try c.decodeIfPresent(OverviewConfig.self, forKey: .overview) ?? .default
    }

    func grid(for displayUUID: String, spaceCount: Int) -> GridLayout {
        if let g = displays[displayUUID] { return g }
        if let g = defaultGrid { return g }
        return .autoFit(spaceCount: spaceCount)
    }

    static var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appending(path: ".config/lattice/config.json")
    }

    static func load() -> Config {
        guard let data = try? Data(contentsOf: configURL) else { return .default }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            Log.log("config: could not parse \(configURL.path): \(error). Using defaults.")
            return .default
        }
    }

    func save() throws {
        let url = Self.configURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: url)
    }
}
