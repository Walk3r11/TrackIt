import SwiftUI

struct SavingsProgressBar: View {
    var title: String
    var progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(Palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.cardAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Palette.accent)
                            .frame(width: proxy.size.width * CGFloat(progress))
                    }
            }
            .frame(height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
