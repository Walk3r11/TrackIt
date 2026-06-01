import SwiftUI

enum AppTypography {
    private static let displayRegular = "AvenirNext-Regular"
    private static let displayBold = "AvenirNext-DemiBold"
    private static let textRegular = "AvenirNext-Regular"
    private static let textMedium = "AvenirNext-Medium"
    private static let textDemiBold = "AvenirNext-DemiBold"
    private static let textBold = "AvenirNext-Bold"

    static func display(size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .largeTitle) -> Font {
        Font.custom(displayFontName(for: weight), size: size, relativeTo: relativeTo)
    }

    static func text(size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .body) -> Font {
        Font.custom(textFontName(for: weight), size: size, relativeTo: relativeTo)
    }

    private static func displayFontName(for weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black:
            return displayBold
        default:
            return displayRegular
        }
    }

    private static func textFontName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            return textBold
        case .semibold:
            return textDemiBold
        case .medium:
            return textMedium
        default:
            return textRegular
        }
    }
}

extension Font {
    static func appFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo: Font.TextStyle = .body
    ) -> Font {
        switch design {
        case .serif:
            return AppTypography.display(size: size, weight: weight, relativeTo: relativeTo)
        case .rounded:
            return AppTypography.text(size: size, weight: weight, relativeTo: relativeTo)
        default:
            return AppTypography.text(size: size, weight: weight, relativeTo: relativeTo)
        }
    }
}
