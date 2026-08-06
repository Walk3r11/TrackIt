import SwiftUI
import UIKit

struct InsightsTab: View {
    @EnvironmentObject private var session: SessionManager
    @Binding var transactions: [Transaction]
    @Binding var cards: [CardInfo]
    @Binding var selectedPeriod: Period

    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedTimeframe: InsightTimeFrame = .month
    @State private var selectedSection: InsightSection = .overview
    var body: some View {
        ZStack {
            AnimatedBackground()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                insightsHeader
                    .padding(.top, 16)
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)

                insightsSectionPicker
                    .padding(.top, 12)
                    .padding(.horizontal, LayoutMetrics.horizontalPadding)

                contentView
            }
        }
        .task(id: selectedTimeframe) {
            await loadData()
        }
        .task(id: selectedSection) {
            await loadData()
        }
        .task(id: transactions.count) {
            await loadData()
        }
        .onDisappear {
            viewModel.cancelAllTasks()
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.stats == nil {
            LoadingView(message: "Calculating insights...")
        } else if let error = viewModel.error {
            ErrorView(error: error) {
                Task { await viewModel.refresh() }
            }
        } else {
            TabView(selection: $selectedSection) {
                LazyView {
                    OverviewTabView(
                        stats: viewModel.stats ?? .empty
                    )
                }
                .tag(InsightSection.overview)

                LazyView {
                    CategoriesTabView(
                        stats: viewModel.stats ?? .empty
                    )
                }
                .tag(InsightSection.categories)

                LazyView {
                    TransactionsTabView(
                        stats: viewModel.stats ?? .empty,
                        cardStats: viewModel.cardStats ?? .empty,
                        largestTransactions: viewModel.largestTransactions,
                        cardsCount: cards.count
                    )
                }
                .tag(InsightSection.transactions)

                LazyView {
                    PatternsTabView(
                        spendingPatterns: viewModel.spendingPatterns ?? .empty,
                        monthlyComparison: viewModel.monthlyComparison
                    )
                }
                .tag(InsightSection.patterns)

                LazyView {
                    AnalysisTabView(
                        stats: viewModel.stats ?? .empty,
                        spendingVelocity: viewModel.spendingVelocity ?? .empty,
                        savingsRate: viewModel.savingsRate ?? .empty,
                        previousStats: viewModel.previousStats
                    )
                }
                .tag(InsightSection.analysis)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .padding(.top, 8)
            .background(ClearPageTabViewBackground())
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        await viewModel.loadData(
            transactions: transactions,
            cards: cards,
            timeframe: selectedTimeframe,
            section: selectedSection,
            balance: session.user?.balance ?? 0
        )
    }
}

// MARK: - Header + Pickers

private extension InsightsTab {
    var insightsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.appFont(size: 26, weight: .semibold))
                .foregroundColor(Palette.primary)
            Text("Spending intelligence at a glance.")
                .font(.appFont(size: 13))
                .foregroundColor(Palette.secondary)

            HorizontalFadeScrollView(showsIndicators: false, fadeWidth: 40, fadeColor: Palette.background) {
                HStack(spacing: 8) {
                    ForEach(InsightTimeFrame.allCases) { timeframe in
                        TimeframeChip(
                            title: timeframe.rawValue,
                            isSelected: selectedTimeframe == timeframe
                        ) {
                            withAnimation(.easeInOut(duration: AppConstants.Animation.defaultDuration)) {
                                selectedTimeframe = timeframe
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .minimalSurface(cornerRadius: 20, fill: Palette.cardAlt)
    }

    var insightsSectionPicker: some View {
        ScrollViewReader { proxy in
            HorizontalFadeScrollView(showsIndicators: false, fadeWidth: 40, fadeColor: Palette.background) {
                HStack(spacing: 12) {
                    ForEach(InsightSection.allCases) { section in
                        SectionCard(
                            title: section.rawValue,
                            icon: section.icon,
                            isSelected: selectedSection == section
                        ) {
                            withAnimation(.easeInOut(duration: AppConstants.Animation.defaultDuration)) {
                                selectedSection = section
                            }
                        }
                        .id(section)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: selectedSection) { _, newSection in
                withAnimation { proxy.scrollTo(newSection, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(selectedSection, anchor: .center) }
        }
    }
}

private struct SectionCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.appFont(size: 12, weight: .semibold))
                Text(title)
                    .font(.appFont(size: 12, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : Palette.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Palette.primary : Palette.card)
            )
            .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98, pressedOpacity: 0.9))
    }
}

private struct TimeframeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appFont(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .white : Palette.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? Palette.primary : Palette.card)
                )
                .overlay(Capsule().stroke(Palette.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98, pressedOpacity: 0.9))
    }
}

private struct ClearPageTabViewBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
