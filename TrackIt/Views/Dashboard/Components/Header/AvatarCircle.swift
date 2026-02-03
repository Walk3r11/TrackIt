import SwiftUI

struct AvatarCircle: View {
    let text: String

    var body: some View {
        Circle()
            .fill(Palette.card)
            .frame(width: 42, height: 42)
            .overlay(
                Text(initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Palette.accent)
            )
            .overlay(Circle().stroke(Palette.stroke, lineWidth: 1))
            .shadow(color: Palette.shadow, radius: 8, y: 6)
    }

    private var initials: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "U" }
        return String(trimmed.prefix(1)).uppercased()
    }
}
