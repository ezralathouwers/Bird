import SwiftUI

enum SpeciesTab: String, CaseIterable {
    case overview = "Overzicht"
    case distribution = "Verspreiding", observations = "Waarnemingen"
}

struct SpeciesTabStrip: View {
    @Binding var selection: SpeciesTab
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SpeciesTab.allCases, id: \.self) { tab in
                    Button { selection = tab } label: {
                        Text(tab.rawValue.uppercased()).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                            .tracking(1.1)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(selection == tab ? FieldGuideTheme.selectedBeige : .clear, in: Capsule())
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                }
            }.padding(.horizontal, 4)
        }
        .background(FieldGuideTheme.beige, in: RoundedRectangle(cornerRadius: 28))
    }
}

struct SpeciesFact: Identifiable {
    let id: String
    let symbol: String
    let value: String
}

struct SpeciesFacts: View {
    // Brief examples only; scientific values await independent source review.
    private let facts = [
        SpeciesFact(id: "Lengte", symbol: "arrow.left.and.right", value: "16–17 cm"),
        SpeciesFact(id: "Gewicht", symbol: "scalemass", value: "26–46 g"),
        SpeciesFact(id: "Spanwijdte", symbol: "spread-wings", value: "24–26 cm"),
        SpeciesFact(id: "Leefgebied", symbol: "water.waves", value: "Rivieren, beken en meren")
    ]
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if typeSize.isAccessibilitySize {
                ForEach(facts) { fact in factRow(fact) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(Array(facts.prefix(3))) { fact in factRow(fact) }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(facts.prefix(3))) { fact in factRow(fact) }
                    }
                }
                if let habitat = facts.last { factRow(habitat) }
            }
            Text("Voorbeeldgegevens · broncontrole volgt").font(FieldGuideTheme.sans(12, relativeTo: .caption)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func factRow(_ fact: SpeciesFact) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Group {
                if fact.symbol == "spread-wings" {
                    SpreadWingsIcon().stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 24, height: 18)
                } else {
                    Image(systemName: fact.symbol).font(.system(.body, weight: .regular))
                }
            }.scaleEffect(0.8).foregroundStyle(FieldGuideTheme.taupe.opacity(0.5)).frame(width: 24)
            Text(fact.value).font(FieldGuideTheme.sans(17, relativeTo: .body)).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.id): \(fact.value)")
    }
}

// Original outline drawing, not a third-party icon asset.
struct SpreadWingsIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            .init(x: 0.50, y: 0.27), .init(x: 0.45, y: 0.20), .init(x: 0.44, y: 0.10),
            .init(x: 0.50, y: 0.05), .init(x: 0.56, y: 0.10), .init(x: 0.55, y: 0.27),
            .init(x: 0.74, y: 0.28), .init(x: 0.99, y: 0.08), .init(x: 0.91, y: 0.39),
            .init(x: 0.83, y: 0.35), .init(x: 0.82, y: 0.49), .init(x: 0.73, y: 0.44),
            .init(x: 0.70, y: 0.58), .init(x: 0.59, y: 0.51), .init(x: 0.55, y: 0.70),
            .init(x: 0.60, y: 0.92), .init(x: 0.50, y: 0.83), .init(x: 0.40, y: 0.92),
            .init(x: 0.45, y: 0.70), .init(x: 0.41, y: 0.51), .init(x: 0.30, y: 0.58),
            .init(x: 0.27, y: 0.44), .init(x: 0.18, y: 0.49), .init(x: 0.17, y: 0.35),
            .init(x: 0.09, y: 0.39), .init(x: 0.01, y: 0.08), .init(x: 0.26, y: 0.28)
        ]
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) })
        path.closeSubpath()
        return path
    }
}

struct KingfisherArtworkCarousel: View {
    @State private var page = 0
    private let descriptions = ["Hoofdillustratie", "In vlucht", "Vooraanzicht", "Achteraanzicht"]
    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $page) {
                ForEach(descriptions.indices, id: \.self) { index in
                    ArtworkPlaceholder(hero: true,
                        accessibilityDescription: "Tijdelijke illustratieplaats: \(descriptions[index])")
                        .padding(.horizontal, 2)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 330)
            HStack(spacing: 0) {
                ForEach(descriptions.indices, id: \.self) { index in
                    Button { withAnimation { page = index } } label: {
                        Circle().fill(page == index ? FieldGuideTheme.taupe : FieldGuideTheme.beige)
                            .frame(width: 7, height: 7).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("\(descriptions[index]), afbeelding \(index + 1) van 4")
                    .accessibilityAddTraits(page == index ? [.isSelected] : [])
                }
            }
        }
    }
}

struct ArtworkPlaceholder: View {
    let hero: Bool
    let accessibilityDescription: String
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(FieldGuideTheme.beige.opacity(0.22))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "bird").font(hero ? .largeTitle : .title3)
                    if hero { Text("Illustratie volgt").font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                }.foregroundStyle(FieldGuideTheme.taupe)
            }
            .accessibilityLabel(accessibilityDescription)
    }
}

struct HabitatFooter: View {
    var body: some View {
        Image("KingfisherHabitat")
            .resizable()
            .scaledToFill()
            .frame(height: 84, alignment: .bottom)
            .clipped()
            .accessibilityHidden(true)
    }
}
