import SwiftUI

struct CategoryDonutBlock: View {
    var title: String
    var totalText: String
    var slices: [CategorySlice]
    var emptyText: String

    var body: some View {
        if slices.isEmpty {
            EmptyDataView(message: emptyText)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.appFont(size: 14, weight: .semibold, design: .serif))
                    .foregroundColor(Palette.primary)
                    .padding(.top, 4)

                ZStack {
                    CategoryDonutChart(slices: slices)
                        .frame(width: 180, height: 180)

                    VStack(spacing: 4) {
                        Text(totalText)
                            .font(.appFont(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Palette.primary)
                        Text("Total")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Palette.tertiary)
                            .textCase(.uppercase)
                            .kerning(0.6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                let columns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(slices.prefix(6)) { slice in
                        CategoryLegendRow(slice: slice)
                    }
                }
                .padding(.bottom, 4)
            }
            .padding(.vertical, 4)
        }
    }

}

struct CategoryDonutChart: View {
    var slices: [CategorySlice]

    var body: some View {
        Canvas { context, size in
            let total = slices.reduce(0) { $0 + $1.value }
            guard total > 0 else { return }


            let inset: CGFloat = 8
            let availableWidth = size.width - (inset * 2)
            let availableHeight = size.height - (inset * 2)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(availableWidth, availableHeight) / 2
            var start = Angle(degrees: -90)

            for slice in slices {
                let end = start + Angle(degrees: (slice.value / total) * 360)
                var path = Path()
                path.addArc(center: center, radius: radius * 0.9, startAngle: start, endAngle: end, clockwise: false)
                context.stroke(
                    path,
                    with: .color(slice.color),
                    style: StrokeStyle(lineWidth: radius * 0.28, lineCap: .butt)
                )
                start = end
            }
        }
        .drawingGroup()
        .background(
            Circle()
                .fill(Palette.card)
        )
        .overlay(
            Circle()
                .stroke(Palette.stroke, lineWidth: 1)
        )
        .clipShape(Circle())
    }
}

struct CategoryLegendRow: View {
    var slice: CategorySlice

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(slice.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(slice.name)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Palette.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(slice.value.formattedAsCurrency())
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Palette.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Text(String(format: "%.0f%%", slice.percentage))
                .font(.caption2.weight(.semibold))
                .foregroundColor(slice.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .minimalSurface(cornerRadius: 12, fill: Palette.card)
    }
}

struct CategoryBarRow: View {
    var slice: CategorySlice
    var totalValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(slice.name)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Palette.primary)
                Spacer()
                Text(slice.value.formattedAsCurrency())
                    .font(.caption)
                    .foregroundColor(Palette.secondary)
            }

            GeometryReader { proxy in
                let ratio = totalValue == 0 ? 0 : slice.value / totalValue
                Capsule()
                    .fill(Palette.cardAlt)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(slice.color)
                            .frame(width: proxy.size.width * CGFloat(min(max(ratio, 0), 1)))
                    }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Empty Data View

struct EmptyDataView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Palette.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        .minimalSurface(cornerRadius: 12, fill: Palette.card)
    }
}
