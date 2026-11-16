import SwiftUI

enum FieldGuideTheme {
    // Provisional: no approved screenshot has been supplied for sampling.
    static let ivory = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let beige = Color(red: 0.82, green: 0.79, blue: 0.74)
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
                .font(.system(.body, weight: .medium))
                .frame(width: 44, height: 44)
                .background(Circle().stroke(FieldGuideTheme.beige, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}
