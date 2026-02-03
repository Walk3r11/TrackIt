import SwiftUI

struct CubertoHeader: View {
    let firstName: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 16) {

            ZStack {
                Circle()
                    .fill(Palette.card)
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(Palette.stroke, lineWidth: 1))

                Text(String(firstName.prefix(1)).uppercased())
                    .font(.appFont(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(Palette.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back! 👋")
                    .font(.appFont(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Palette.tertiary)
                    .textCase(.uppercase)
                    .kerning(0.6)
                Text("\(firstName)")
                    .font(.appFont(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(Palette.primary)
                    .lineLimit(1)
            }

            Spacer()


            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.appFont(size: 16, weight: .bold))
                    .foregroundColor(Palette.accent)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Palette.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Palette.stroke, lineWidth: 1)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Add transaction")
        }
        .padding(.vertical, 10)
    }
}
