import SwiftUI
import MapKit
import UIKit

enum FieldGuideTheme {
    // Provisional: no approved screenshot has been supplied for sampling.
    static func sans(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("DMSans-9ptRegular", size: size, relativeTo: style)
    }
    // Native muted cartography, shared by range, observation and location maps.
    static var mapStyle: MapStyle {
        .standard(elevation: .flat, emphasis: .muted,
                  pointsOfInterest: .excludingAll, showsTraffic: false)
    }
    static let controlCornerRadius: CGFloat = 18
    static let roundControlDiameter: CGFloat = 44
    // One physical stroke width for every navigation outline, independent of
    // icon size. SF Symbol weights alone do not guarantee identical widths.
    static let navigationStroke = StrokeStyle(lineWidth: 0.7, lineCap: .round, lineJoin: .round)
    static let navigationWhite = Color.white
    static let mapLegendBackground = Color(red: 0.995, green: 0.99, blue: 0.98)
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
                        in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius, style: .continuous)
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

// Explicit controls avoid iOS's automatic glass toolbar treatment.
struct SpeciesBackButton: View {
    var label = "Terug"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .light))
                .frame(width: 44, height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(FieldGuideTheme.charcoal)
            .accessibilityLabel(label)
    }
}

struct MapCloseButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 20, weight: .light))
                .foregroundStyle(FieldGuideTheme.charcoal)
                .frame(width: 44, height: 44)
                .background(FieldGuideTheme.ivory, in: Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct LocationOutlineMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10.5, y: 21.5))
        path.addCurve(to: CGPoint(x: 3, y: 9), control1: CGPoint(x: 8, y: 18), control2: CGPoint(x: 3, y: 14))
        path.addCurve(to: CGPoint(x: 21, y: 9), control1: CGPoint(x: 3, y: -2), control2: CGPoint(x: 21, y: -2))
        path.addCurve(to: CGPoint(x: 13.5, y: 21.5), control1: CGPoint(x: 21, y: 14), control2: CGPoint(x: 16, y: 18))
        path.addQuadCurve(to: CGPoint(x: 10.5, y: 21.5), control: CGPoint(x: 12, y: 23.5))
        path.closeSubpath()
        path.addEllipse(in: CGRect(x: 9, y: 6, width: 6, height: 6))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

struct EditOutlineMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 3, y: 21))
        path.addLine(to: CGPoint(x: 4.5, y: 15))
        path.addLine(to: CGPoint(x: 17, y: 2.5))
        path.addQuadCurve(to: CGPoint(x: 21.5, y: 7), control: CGPoint(x: 23, y: 1))
        path.addLine(to: CGPoint(x: 9, y: 19.5))
        path.closeSubpath()
        path.move(to: CGPoint(x: 14.5, y: 5))
        path.addLine(to: CGPoint(x: 19, y: 9.5))
        path.move(to: CGPoint(x: 4.5, y: 15))
        path.addLine(to: CGPoint(x: 9, y: 19.5))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

struct CountryFlagBadge: View {
    let code: String
    var diameter: CGFloat = 36
    var body: some View {
        Group {
            if let normalized = ObservationCountry.normalized(code), UIImage(named: "flag-" + normalized.lowercased()) != nil {
                Image("flag-" + normalized.lowercased()).resizable().scaledToFill().saturation(0.72)
            } else {
                FieldGuideTheme.beige.overlay { Image(systemName: "globe").foregroundStyle(FieldGuideTheme.taupe) }
            }
        }
        .frame(width: diameter, height: diameter).clipShape(Circle())
        .accessibilityLabel(ObservationCountry.name(for: code))
    }
}

struct CenteredPageHeader: View {
    let title: String
    var countryCode: String? = nil
    let back: () -> Void
    var body: some View {
        ZStack {
            HStack { SpeciesBackButton(action: back); Spacer(minLength: 0) }
            HStack(spacing: 8) {
                if let countryCode { CountryFlagBadge(code: countryCode, diameter: 22) }
                Text(title).font(FieldGuideTheme.sans(17, relativeTo: .headline))
                    .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            }.padding(.horizontal, 44)
        }
        .frame(minHeight: 44).padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 8)
        .foregroundStyle(FieldGuideTheme.charcoal)
    }
}

struct ObservationTotal: View {
    let value: Int
    let label: String
    var body: some View {
        Text("\(value)").font(FieldGuideTheme.sans(60, relativeTo: .title3))
            .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.35))
            .accessibilityLabel("\(value) \(label)").accessibilityAddTraits(.isHeader)
    }
}

// The visible control has the same 18-point corners as search/text fields.
// The native date/time picker lives in a sheet rather than imposing its pill.
struct DateTimeField: View {
    let title: String
    @Binding var selection: Date
    let isDate: Bool
    var latestDate: Date? = nil
    @State private var presented = false
    private var value: String {
        isDate ? selection.formatted(date: .abbreviated, time: .omitted)
               : selection.formatted(date: .omitted, time: .shortened)
    }
    var body: some View {
        Button { presented = true } label: {
            Text(value).font(FieldGuideTheme.sans(17)).lineLimit(1)
                .modifier(RoundedSearchField())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(value)
            .sheet(isPresented: $presented) {
                NavigationStack {
                    Group {
                        if let latestDate {
                            DatePicker(title, selection: $selection, in: ...latestDate,
                                       displayedComponents: isDate ? .date : .hourAndMinute)
                        } else {
                            DatePicker(title, selection: $selection,
                                       displayedComponents: isDate ? .date : .hourAndMinute)
                        }
                    }.datePickerStyle(.wheel).labelsHidden().padding(20)
                        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("Klaar") { presented = false }
                        } }
                }.presentationDetents([.height(340)])
            }
    }
}

struct SpeciesMapBadge: View {
    let species: Species
    var body: some View {
        Group {
            if UIImage(named: SpeciesMediaRole.classic.assetName(for: species)) != nil {
                PrimaryBirdImage(species: species).frame(width: 28, height: 28)
            } else {
                Image(systemName: "bird").font(.system(size: 20, weight: .light))
            }
        }
        .frame(width: 44, height: 44)
        .background(FieldGuideTheme.ivory, in: Circle())
        .accessibilityLabel(species.dutchName)
    }
}

struct RoundEditAction: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            EditOutlineMark().stroke(style: FieldGuideTheme.navigationStroke).frame(width: 22, height: 22)
                .frame(width: 44, height: 44)
                .background(Circle().stroke(FieldGuideTheme.beige, lineWidth: 0.75))
                .contentShape(Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
struct FineSearchMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 1.5, y: 1.5, width: 15.5, height: 15.5))
        path.move(to: CGPoint(x: 14.8, y: 14.8)); path.addLine(to: CGPoint(x: 22.5, y: 22.5))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
