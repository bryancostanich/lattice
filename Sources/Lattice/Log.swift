import Foundation

enum Log {
    static let path = "/tmp/lattice.log"

    private static let handle: FileHandle? = {
        FileManager.default.createFile(atPath: path, contents: nil)
        return FileHandle(forWritingAtPath: path)
    }()

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ msg: String) {
        let line = "\(formatter.string(from: Date())) [lattice] \(msg)\n"
        FileHandle.standardError.write(Data(line.utf8))
        handle?.write(Data(line.utf8))
    }
}
