import Foundation

// Immutable, shared offline index. Load/query it away from the main actor.
struct CountryBoundaryIndex: Sendable {
    private struct Point: Sendable { let x: Double; let y: Double }
    private struct Polygon: Sendable {
        let code: String
        let bounds: [Double]
        let rings: [[Point]]
    }
    private let polygons: [Polygon]
    static let bundled: Result<CountryBoundaryIndex, Error> = Result {
        guard let url = Bundle.main.url(forResource: "CountryBoundaries", withExtension: "bin") else {
            throw CountryBoundaryError.unavailable
        }
        return try CountryBoundaryIndex(data: Data(contentsOf: url))
    }

    init(data: Data) throws {
        var reader = Reader(data: data)
        guard try reader.bytes(8) == Data("BIRDCTR1".utf8) else { throw CountryBoundaryError.unavailable }
        let count = Int(try reader.integer())
        guard (1...50_000).contains(count) else { throw CountryBoundaryError.unavailable }
        var result: [Polygon] = []
        for _ in 0..<count {
            guard let code = String(data: try reader.bytes(2), encoding: .ascii),
                  code.utf8.allSatisfy({ (65...90).contains($0) }) else { throw CountryBoundaryError.unavailable }
            let bounds = try (0..<4).map { _ in try reader.number() }
            let ringCount = Int(try reader.integer())
            guard bounds.allSatisfy(\.isFinite), bounds[0] <= bounds[2], bounds[1] <= bounds[3],
                  (1...10_000).contains(ringCount) else { throw CountryBoundaryError.unavailable }
            var rings: [[Point]] = []
            for _ in 0..<ringCount {
                let pointCount = Int(try reader.integer())
                guard (4...1_000_000).contains(pointCount), pointCount <= reader.remaining / 8 else { throw CountryBoundaryError.unavailable }
                var ring: [Point] = []
                ring.reserveCapacity(pointCount)
                for _ in 0..<pointCount {
                    let x = try reader.number(), y = try reader.number()
                    guard x.isFinite, y.isFinite, (-180...180).contains(x), (-90...90).contains(y) else { throw CountryBoundaryError.unavailable }
                    ring.append(Point(x: x, y: y))
                }
                rings.append(ring)
            }
            result.append(Polygon(code: code, bounds: bounds, rings: rings))
        }
        guard reader.remaining == 0 else { throw CountryBoundaryError.unavailable }
        polygons = result
    }

    func country(latitude: Double, longitude: Double) -> String? {
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        var matches = Set<String>()
        for polygon in polygons {
            let b = polygon.bounds
            guard longitude >= b[0], longitude <= b[2], latitude >= b[1], latitude <= b[3],
                  let outer = polygon.rings.first, contains(outer, x: longitude, y: latitude),
                  !polygon.rings.dropFirst().contains(where: { contains($0, x: longitude, y: latitude) }) else { continue }
            matches.insert(polygon.code)
        }
        // A point exactly on conflicting borders has no uniquely inferred country.
        return matches.count == 1 ? matches.first : nil
    }

    private func contains(_ ring: [Point], x: Double, y: Double) -> Bool {
        var inside = false
        var previous = ring[ring.count - 1]
        for point in ring {
            if (point.y > y) != (previous.y > y),
               x < (previous.x - point.x) * (y - point.y) / (previous.y - point.y) + point.x {
                inside.toggle()
            }
            previous = point
        }
        return inside
    }

    private struct Reader {
        let data: Data
        var offset = 0
        var remaining: Int { data.count - offset }
        mutating func bytes(_ count: Int) throws -> Data {
            guard count >= 0, remaining >= count else { throw CountryBoundaryError.unavailable }
            defer { offset += count }
            return data.subdata(in: offset..<(offset + count))
        }
        mutating func integer() throws -> UInt32 {
            guard remaining >= 4 else { throw CountryBoundaryError.unavailable }
            let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian }
            offset += 4
            return value
        }
        mutating func number() throws -> Double { Double(Float(bitPattern: try integer())) }
    }
}

enum CountryBoundaryError: LocalizedError {
    case unavailable
    var errorDescription: String? { "De lokale landgrenzen konden niet worden geladen. Je waarnemingen blijven bewaard." }
}
