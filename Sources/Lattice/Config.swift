import Foundation

struct Config: Codable {
    var displays: [String: GridLayout]
    var defaultGrid: GridLayout?
    var wrap: Bool

    static let `default` = Config(displays: [:], defaultGrid: nil, wrap: false)

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
        guard let data = try? Data(contentsOf: configURL),
              let cfg = try? JSONDecoder().decode(Config.self, from: data)
        else { return .default }
        return cfg
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
