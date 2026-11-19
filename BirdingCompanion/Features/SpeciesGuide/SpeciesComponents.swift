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
        .frame(maxWidth: .infinity)
        .background(FieldGuideTheme.beige, in: RoundedRectangle(cornerRadius: 28))
    }
}

struct SpeciesFact: Identifiable {
    let id: String
    let symbol: String?
    let value: String
}

struct SpeciesFacts: View {
    let species: Species
    // Brief examples only; scientific values await independent source review.
    private let facts = [
        SpeciesFact(id: "Spanwijdte", symbol: nil, value: "24–26 cm")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if species.id == MockSpeciesRepository.kingfisher.id {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(facts) { fact in factRow(fact) }
                Text("De ijsvogel leeft langs helder water, bij beken, rivieren en plassen. Vanaf een tak duikt hij naar kleine vissen. Steile oevers bieden plek voor zijn nest.")
                    .font(FieldGuideTheme.sans(16, relativeTo: .body).weight(.light))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            Text("Spanwijdte: voorbeeldwaarde · broncontrole volgt").font(FieldGuideTheme.sans(12, relativeTo: .caption)).foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
            } else {
                Text("Soortbeschrijving en spanwijdte volgen na broncontrole.")
                    .font(FieldGuideTheme.sans(16, relativeTo: .body))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func factRow(_ fact: SpeciesFact) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let symbol = fact.symbol {
                Image(systemName: symbol)
                    .font(.system(.body, weight: .regular))
                    .scaleEffect(0.8)
                    .foregroundStyle(FieldGuideTheme.taupe.opacity(0.5))
                    .frame(width: 24)
            }
            Text(fact.value)
                .font(fact.id == "Spanwijdte"
                      ? FieldGuideTheme.sans(20, relativeTo: .title3)
                      : FieldGuideTheme.sans(17, relativeTo: .body))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.id): \(fact.value)")
    }
}

struct SpeciesArtworkCarousel: View {
    let species: Species
    @State private var page = 0
    private let slides = SpeciesMediaRole.detailSlides
    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $page) {
                ForEach(slides.indices, id: \.self) { index in
                    Group {
                        let role = slides[index]
                        if UIImage(named: role.assetName(for: species)) != nil {
                            Image(role.assetName(for: species)).resizable().scaledToFit()
                                .accessibilityLabel("\(role.label) van \(species.dutchName)")
                        } else {
                            ArtworkPlaceholder(hero: true,
                                accessibilityDescription: "\(role.label) van \(species.dutchName) nog niet beschikbaar",
                                message: role.missingMessage)
                        }
                    }
                    .padding(.vertical, 6)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 330)
            HStack(spacing: 0) {
                ForEach(slides.indices, id: \.self) { index in
                    Button { withAnimation { page = index } } label: {
                        Circle().fill(page == index ? FieldGuideTheme.taupe : FieldGuideTheme.beige)
                            .frame(width: 7, height: 7).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("\(slides[index].label), afbeelding \(index + 1) van 4")
                    .accessibilityAddTraits(page == index ? [.isSelected] : [])
                }
            }
        }
    }
}

struct ArtworkPlaceholder: View {
    let hero: Bool
    let accessibilityDescription: String
    var message = "Illustratie volgt"
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(FieldGuideTheme.beige.opacity(0.22))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "bird").font(hero ? .largeTitle : .title3)
                    if hero { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
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

// Original outline drawing with deliberately no pupil for the not-yet-logged state.
struct PupilFreeEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.5))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY),
                          control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.5))
        path.closeSubpath()
        return path
    }
}
