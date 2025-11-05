//
//  ContentView.swift
//  TrackIt
//
//  Created by Konstantin Nikolow on 5.11.25.
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Motion Manager
@MainActor
final class MotionManager: ObservableObject {
    private let motion = CMMotionManager()
    @Published var pitch: Double = 0
    @Published var roll: Double = 0

    init() {
        #if targetEnvironment(simulator)
        #else
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 60.0
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data = data else { return }
                self.pitch = data.attitude.pitch
                self.roll = data.attitude.roll
            }
        }
        #endif
    }

    deinit {
        #if !targetEnvironment(simulator)
        motion.stopDeviceMotionUpdates()
        #endif
    }
}

// MARK: - Period Enum
enum Period: String, CaseIterable {
    case daily, weekly, biweekly, monthly, quarterly, semiannual, nineMonth, yearly
}

// MARK: - Content View
struct ContentView: View {
    @State private var selectedPeriod: Period = .monthly
    @State private var shimmerOffset: CGFloat = -300
    @StateObject private var motion = MotionManager()
    @State private var hueRotation: Angle = .degrees(0)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .indigo.opacity(0.35), .purple.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .hueRotation(hueRotation)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 25).repeatForever(autoreverses: true)) {
                    hueRotation = .degrees(60)
                }
            }

            VStack(spacing: 30) {
                HeaderView()
                LiquidGlassCardView(shimmerOffset: shimmerOffset, motion: motion)
                PeriodPicker(selectedPeriod: $selectedPeriod)
                ChartPlaceholderView()
                InsightsCardView()
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 60)
        }
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Header
struct HeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("TrackIt")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.3), radius: 8)
                Text("Your financial universe")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.title)
                .foregroundStyle(.white.opacity(0.9))
                .padding(12)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.5), .blue.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .cyan.opacity(0.3), radius: 10)
        }
    }
}

// MARK: - Liquid Glass Background
struct LiquidGlassBackground: View {
    var cornerRadius: CGFloat = 30
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.08), .white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: .cyan.opacity(0.25), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Liquid Glass Card
struct LiquidGlassCardView: View {
    var shimmerOffset: CGFloat
    @ObservedObject var motion: MotionManager
    @State private var pulse = false

    var body: some View {
        ZStack {
            LiquidGlassBackground(cornerRadius: 30)
                .rotation3DEffect(.degrees(motion.pitch * 10), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(motion.roll * -10), axis: (x: 0, y: 1, z: 0))
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .white.opacity(0.0),
                            .white.opacity(0.25),
                            .white.opacity(0.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blendMode(.overlay)
                    .mask(RoundedRectangle(cornerRadius: 30))
                    .offset(x: shimmerOffset)
                )

            VStack(spacing: 12) {
                Text("Total Balance")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                Text("$12,840.50")
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .teal, .blue],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .shadow(color: .cyan.opacity(0.4), radius: 10)
                    .scaleEffect(pulse ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)
                Text("as of today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 35)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .onAppear {
            pulse.toggle()
        }
    }
}

// MARK: - Period Picker
// MARK: - Period Picker
struct PeriodPicker: View {
    @Binding var selectedPeriod: Period

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Period.allCases, id: \.self) { period in
                    let isSelected = selectedPeriod == period

                    let activeBackground = LinearGradient(
                        colors: [.cyan.opacity(0.7), .blue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    let inactiveBackground = Color.white.opacity(0.05)

                    let backgroundShape = RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected
                              ? AnyShapeStyle(activeBackground)
                              : AnyShapeStyle(inactiveBackground))

                    let borderShape = RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.cyan.opacity(0.6)
                                           : Color.white.opacity(0.1),
                                lineWidth: 1)

                    Text(period.rawValue.capitalized)
                        .font(.subheadline.bold())
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(ZStack { backgroundShape; borderShape })
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                selectedPeriod = period
                            }
                        }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
        }
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white, location: 0.08),
                    .init(color: .white, location: 0.92),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}


// MARK: - Chart Placeholder
struct ChartPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Overview")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)
            ZStack {
                LiquidGlassBackground(cornerRadius: 25)
                Text("Chart Placeholder")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.callout)
            }
            .frame(height: 180)
            .padding(.horizontal)
        }
    }
}

// MARK: - Insights Card
struct InsightsCardView: View {
    var body: some View {
        ZStack {
            LiquidGlassBackground(cornerRadius: 25)
            VStack(alignment: .leading, spacing: 10) {
                Text("Smart Insights")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.85))
                Text("💡 Personalized tips and AI insights will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
