import SwiftUI

enum CategoryColors {
    private struct StoredColor: Codable {
        var hue: Double
        var saturation: Double
        var brightness: Double
    }

    private static let storageKey = "categoryColorMap.v1"
    private static let lock = NSLock()
    private static var cached: [String: StoredColor] = load()

    static func color(for category: String) -> Color {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.isEmpty ? "Other" : trimmed.lowercased()

        lock.lock()
        defer { lock.unlock() }

        if let stored = cached[key] {
            return Color(hue: stored.hue, saturation: stored.saturation, brightness: stored.brightness)
        }

        let stored = assignNewColor(forKey: key, existing: cached)
        cached[key] = stored
        persist(cached)
        return Color(hue: stored.hue, saturation: stored.saturation, brightness: stored.brightness)
    }

    private static func assignNewColor(forKey key: String, existing: [String: StoredColor]) -> StoredColor {
        let golden: Double = 0.618033988749895
        let seed = hash01(key)
        let baseHue = frac(seed * 0.83 + 0.11)

        let existingHues = existing.values.map(\.hue)
        var bestHue = baseHue
        var bestScore: Double = -1

        for i in 0..<24 {
            let candidate = frac(baseHue + Double(i) * golden)
            let score = minHueDistance(candidate, existingHues)
            if score > bestScore {
                bestScore = score
                bestHue = candidate
            }
        }

        let sat = 0.78 + (hash01(key + "|s") * 0.12)
        let bri = 0.88 + (hash01(key + "|b") * 0.10)
        return StoredColor(hue: bestHue, saturation: clamp01(sat), brightness: clamp01(bri))
    }

    private static func minHueDistance(_ hue: Double, _ others: [Double]) -> Double {
        guard !others.isEmpty else { return 1 }
        return others.map { circularDistance(hue, $0) }.min() ?? 1
    }

    private static func circularDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b)
        return min(d, 1 - d)
    }

    private static func load() -> [String: StoredColor] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [:] }
        return (try? JSONDecoder().decode([String: StoredColor].self, from: data)) ?? [:]
    }

    private static func persist(_ map: [String: StoredColor]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func hash01(_ string: String) -> Double {
        var hash: UInt64 = 1469598103934665603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Double(hash % 10_000_000) / 10_000_000.0
    }

    private static func frac(_ x: Double) -> Double {
        x - floor(x)
    }

    private static func clamp01(_ x: Double) -> Double {
        min(1, max(0, x))
    }
}
