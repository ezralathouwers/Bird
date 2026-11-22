import SwiftUI

enum FieldGuideTheme {
    // Provisional: no approved screenshot has been supplied for sampling.
    static func sans(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("DMSans-9ptRegular", size: size, relativeTo: style)
    }
    static let roundControlDiameter: CGFloat = 44
    // One physical stroke width for every navigation outline, independent of
    // icon size. SF Symbol weights alone do not guarantee identical widths.
    static let navigationStroke = StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round)
    static let navigationWhite = Color.white
    static let ivory = Color(red: 0.96, green: 0.95, blue: 0.92)
    static let beige = Color(red: 0.89, green: 0.86, blue: 0.82)
    static let selectedBeige = Color(red: 0.83, green: 0.79, blue: 0.73)
    // Opaque equivalent of 40% beige over ivory, so scrolled content cannot show through.
    static let searchControlBackground = Color(red: 0.932, green: 0.914, blue: 0.88)
    static let khaki = Color(red: 133.0 / 255, green: 131.0 / 255, blue: 107.0 / 255)
    static let navigationOlive = Color(red: 124.0 / 255, green: 135.0 / 255, blue: 48.0 / 255)
    static let mutedIcon = Color(red: 181.0 / 255, green: 165.0 / 255, blue: 142.0 / 255)
    static let taupe = Color(red: 107.0 / 255, green: 104.0 / 255, blue: 100.0 / 255)
    // Neutral warm grey text (#4B4946), shared with the observation button fill.
    static let charcoal = Color(red: 75.0 / 255, green: 73.0 / 255, blue: 70.0 / 255)
}

// Shared large sans-serif headings; Discover sets its own explicit line height.
struct LargeHeadingStyle: ViewModifier {
    private let size: CGFloat
    @ScaledMetric private var tracking: CGFloat

    init(size: CGFloat = 34) {
        self.size = size
        _tracking = ScaledMetric(wrappedValue: size * 0.01, relativeTo: .largeTitle)
    }

    func body(content: Content) -> some View {
        content
            .font(FieldGuideTheme.sans(size, relativeTo: .largeTitle).weight(.medium).leading(.tight))
            .tracking(tracking)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct RoundedSearchField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(FieldGuideTheme.navigationWhite,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(FieldGuideTheme.beige, lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
    }
}

// Tracking is expressed as -0.02 em and follows the same Dynamic Type scale
// as the font, so headings and small species names use the same proportion.
struct SerifText: View {
    private let value: String
    private let baseSize: CGFloat
    private let style: Font.TextStyle
    @ScaledMetric private var scaledSize: CGFloat

    init(_ value: String, size: CGFloat, relativeTo style: Font.TextStyle) {
        self.value = value
        self.baseSize = size
        self.style = style
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: style)
    }

    var body: some View {
        Text(value)
            .font(.custom("Fraunces-9ptBlack", size: baseSize, relativeTo: style).weight(.regular))
            .tracking(-0.02 * scaledSize)
    }
}

struct RoundAction: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.body, weight: .light))
                .frame(width: FieldGuideTheme.roundControlDiameter, height: FieldGuideTheme.roundControlDiameter)
                .background(Circle().stroke(FieldGuideTheme.beige, lineWidth: 0.75))
        }
        .accessibilityLabel(label)
    }
}
