import SwiftUI

struct LineSpark: View {
    var values: [Double]
    var accent: Color = Palette.accent

    var body: some View {
        GeometryReader { proxy in
            let points = normalize(values: values, size: proxy.size)
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

            ZStack(alignment: .leading) {
                shape
                    .fill(Palette.cardAlt)
                    .overlay(shape.stroke(Palette.stroke, lineWidth: 1))

                if points.count >= 2 {

                    Path { path in
                        path.move(to: points[0])
                        addSmoothLine(into: &path, points: points)
                    }
                    .stroke(accent.opacity(0.9), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))


                    Path { path in
                        guard let first = points.first, let last = points.last else { return }
                        path.move(to: CGPoint(x: first.x, y: proxy.size.height))
                        path.addLine(to: first)
                        addSmoothLine(into: &path, points: points)
                        path.addLine(to: CGPoint(x: last.x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(accent.opacity(0.16))
                }
            }
        }
        .drawingGroup()
    }

    // MARK: - Private Methods

    private func addSmoothLine(into path: inout Path, points: [CGPoint], tension: CGFloat = 1) {
        guard points.count >= 2 else { return }
        if points.count == 2 {
            path.addLine(to: points[1])
            return
        }

        for idx in 0..<(points.count - 1) {
            let p0 = points[max(idx - 1, 0)]
            let p1 = points[idx]
            let p2 = points[idx + 1]
            let p3 = points[min(idx + 2, points.count - 1)]

            let d1 = CGPoint(x: (p2.x - p0.x) / 6 * tension, y: (p2.y - p0.y) / 6 * tension)
            let d2 = CGPoint(x: (p3.x - p1.x) / 6 * tension, y: (p3.y - p1.y) / 6 * tension)

            let control1 = CGPoint(x: p1.x + d1.x, y: p1.y + d1.y)
            let control2 = CGPoint(x: p2.x - d2.x, y: p2.y - d2.y)

            path.addCurve(to: p2, control1: control1, control2: control2)
        }
    }

    private func normalize(values: [Double], size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let range = max(maxValue - minValue, 0.0001)
        let insetX: CGFloat = 14
        let insetY: CGFloat = 10
        let w = max(1, size.width - insetX * 2)
        let h = max(1, size.height - insetY * 2)

        return values.enumerated().map { idx, v in
            let t = CGFloat(idx) / CGFloat(values.count - 1)
            let x = insetX + w * t
            let normalized = (v - minValue) / range
            let y = insetY + (1 - CGFloat(normalized)) * h
            return CGPoint(x: x, y: y)
        }
    }
}
