import Foundation

enum Direction: String, Codable {
    case left, right, up, down
}

struct GridLayout: Codable, Equatable {
    var cols: Int
    var rows: Int

    static func autoFit(spaceCount: Int) -> GridLayout {
        let n = max(1, spaceCount)
        let cols = Int(ceil(Double(n).squareRoot()))
        let rows = Int(ceil(Double(n) / Double(cols)))
        return GridLayout(cols: cols, rows: rows)
    }

    func position(for index: Int) -> (col: Int, row: Int) {
        (index % cols, index / cols)
    }

    func index(col: Int, row: Int) -> Int {
        row * cols + col
    }

    func target(from currentIndex: Int, direction: Direction, count: Int, wrap: Bool) -> Int? {
        var (col, row) = position(for: currentIndex)
        switch direction {
        case .left:  col -= 1
        case .right: col += 1
        case .up:    row -= 1
        case .down:  row += 1
        }

        if wrap {
            col = (col % cols + cols) % cols
            row = (row % rows + rows) % rows
        } else {
            guard (0..<cols).contains(col), (0..<rows).contains(row) else { return nil }
        }

        let target = index(col: col, row: row)
        guard target >= 0, target < count else { return nil }
        return target
    }
}
