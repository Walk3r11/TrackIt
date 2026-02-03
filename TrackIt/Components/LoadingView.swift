import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(Palette.secondary)
        }
        .padding(24)
        .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let error: Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(Palette.warning)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(Palette.secondary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Palette.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Palette.card, in: Capsule())
                .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .minimalSurface(cornerRadius: 18, fill: Palette.cardAlt)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SavingsWarningBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Palette.warning)
            Text("Consider increasing your savings rate to \(Int(AppConstants.Insights.recommendedSavingsRate))% or more")
                .font(.caption)
                .foregroundColor(Palette.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Palette.warning.opacity(0.4), lineWidth: 1)
        )
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    @State private var hasAppeared = false

    init(@ViewBuilder _ build: @escaping () -> Content) {
        self.build = build
    }

    var body: some View {
        Group {
            if hasAppeared {
                build()
            } else {
                Color.clear
                    .onAppear { hasAppeared = true }
            }
        }
    }
}
