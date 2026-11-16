import SwiftUI

enum SpeciesTab: String, CaseIterable {
    case overview = "Overzicht", identification = "Herkenning", sound = "Geluid"
    case distribution = "Verspreiding", observations = "Waarnemingen"
}

struct SpeciesTabStrip: View {
    @Binding var selection: SpeciesTab
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SpeciesTab.allCases, id: \.self) { tab in
                    Button { selection = tab } label: {
                        Text(tab.rawValue).font(.system(.subheadline, weight: .medium))
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background(selection == tab ? FieldGuideTheme.ivory : .clear, in: Capsule())
                    }
                    .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
                }
            }.padding(5)
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
        SpeciesFact(id: "Lengte", symbol: "ruler", value: "16–17 cm"),
        SpeciesFact(id: "Gewicht", symbol: "scalemass", value: "26–46 g"),
        SpeciesFact(id: "Spanwijdte", symbol: "arrow.left.and.right", value: "24–26 cm"),
        SpeciesFact(id: "Leefgebied", symbol: "water.waves", value: "Rivieren, beken, meren en waterrijke gebieden"),
        SpeciesFact(id: "Verspreiding", symbol: "globe.europe.africa", value: "Europa, Azië, Afrika")
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
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(Array(facts.suffix(2))) { fact in factRow(fact) }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(facts.suffix(2))) { fact in factRow(fact) }
                    }
                }
            }
            Text("Voorbeeldgegevens · broncontrole volgt").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func factRow(_ fact: SpeciesFact) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: fact.symbol).font(.system(.body, weight: .regular))
                .foregroundStyle(FieldGuideTheme.taupe).frame(width: 24)
            Text(fact.value).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.id): \(fact.value)")
    }
}

struct KingfisherArtworkComposition: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ArtworkPlaceholder(hero: true, accessibilityDescription: "Tijdelijke plaatsaanduiding voor de hoofdillustratie van de ijsvogel")
                    .frame(width: geometry.size.width * 0.64, height: geometry.size.height * 0.96)
                    .position(x: geometry.size.width * 0.32, y: geometry.size.height * 0.50)
                ArtworkPlaceholder(hero: false, accessibilityDescription: "Tijdelijke plaatsaanduiding voor ijsvogel in vlucht")
                    .frame(width: geometry.size.width * 0.34, height: geometry.size.height * 0.32)
                    .position(x: geometry.size.width * 0.83, y: geometry.size.height * 0.32)
                ArtworkPlaceholder(hero: false, accessibilityDescription: "Tijdelijke plaatsaanduiding voor vooraanzicht")
                    .frame(width: geometry.size.width * 0.17, height: geometry.size.height * 0.30)
                    .position(x: geometry.size.width * 0.72, y: geometry.size.height * 0.77)
                ArtworkPlaceholder(hero: false, accessibilityDescription: "Tijdelijke plaatsaanduiding voor achteraanzicht")
                    .frame(width: geometry.size.width * 0.17, height: geometry.size.height * 0.30)
                    .position(x: geometry.size.width * 0.92, y: geometry.size.height * 0.77)
            }
        }
        .aspectRatio(1.12, contentMode: .fit)
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
                    if hero { Text("Illustratie volgt").font(.footnote) }
                }.foregroundStyle(FieldGuideTheme.taupe)
            }
            .accessibilityLabel(accessibilityDescription)
    }
}
