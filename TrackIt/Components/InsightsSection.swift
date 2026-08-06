import SwiftUI

struct InsightsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Palette.cardAlt)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.appFont(size: 13, weight: .semibold))
                            .foregroundColor(Palette.primary)
                    )

                Text(title)
                    .font(.appFont(size: 15, weight: .semibold))
                    .foregroundColor(Palette.primary)
            }

            Divider()
                .background(Palette.stroke)

            content
        }
        .padding(16)
        .minimalSurface(cornerRadius: 20, fill: Palette.cardAlt)
    }
}
