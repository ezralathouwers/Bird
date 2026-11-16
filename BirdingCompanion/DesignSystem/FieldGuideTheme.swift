import SwiftUI

enum FieldGuideTheme {
    // Provisional: no approved screenshot has been supplied for sampling.
    static func sans(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("DMSans-9ptRegular", size: size, relativeTo: style)
    }
    static let speciesTitle = Font.custom("Fraunces-9ptBlack", size: 34, relativeTo: .largeTitle).weight(.regular)
    static let ivory = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let beige = Color(red: 0.89, green: 0.86, blue: 0.82)
    static let selectedBeige = Color(red: 0.83, green: 0.79, blue: 0.73)
    static let taupe = Color(red: 0.42, green: 0.38, blue: 0.33)
    static let charcoal = Color(red: 0.18, green: 0.17, blue: 0.16)
}

struct RoundAction: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .light))
                .frame(width: 44, height: 44)
                .background(Circle().stroke(FieldGuideTheme.beige, lineWidth: 0.75))
        }
        .accessibilityLabel(label)
    }
}
