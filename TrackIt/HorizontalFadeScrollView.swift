import SwiftUI

struct HorizontalFadeScrollView<Content: View>: View {
    var showsIndicators: Bool = false
    var fadeWidth: CGFloat = 24
    var fadeEnabled: Bool = true
    var fadeColor: Color = Palette.backgroundMid
    @ViewBuilder var content: () -> Content

    @State private var contentSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero
    @State private var scrollOffset: CGFloat = 0

    private var canScroll: Bool {
        contentSize.width > containerSize.width + 1
    }

    private var showLeftFade: Bool {
        fadeEnabled && canScroll && scrollOffset > 5
    }

    private var showRightFade: Bool {
        fadeEnabled && canScroll && scrollOffset < (contentSize.width - containerSize.width - 5)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ContentSizeKey.self, value: geo.size)
                            .preference(key: HFadeScrollOffsetKey.self, value: -geo.frame(in: .named("hfade")).minX)
                    }
                )
        }
        .coordinateSpace(name: "hfade")
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ContainerSizeKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(ContentSizeKey.self) { contentSize = $0 }
        .onPreferenceChange(ContainerSizeKey.self) { containerSize = $0 }
        .onPreferenceChange(HFadeScrollOffsetKey.self) { scrollOffset = $0 }
        .overlay(alignment: .leading) {
            if showLeftFade {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [fadeColor, fadeColor.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fadeWidth, height: containerSize.height)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .trailing) {
            if showRightFade {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [fadeColor.opacity(0), fadeColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fadeWidth, height: containerSize.height)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct ContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct ContainerSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct HFadeScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
