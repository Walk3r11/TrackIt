import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var pressedOpacity: Double = 0.9
    var animation: Animation = .spring(response: 0.28, dampingFraction: 0.75)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(animation, value: configuration.isPressed)
    }
}
