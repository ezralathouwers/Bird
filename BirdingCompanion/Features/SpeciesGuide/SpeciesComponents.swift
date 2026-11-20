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
    @State private var showCatalogSources = false
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
            Button("Bronnen soortenlijst") { showCatalogSources = true }
                .font(FieldGuideTheme.sans(12, relativeTo: .caption)).frame(minHeight: 44)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $showCatalogSources) { SpeciesCatalogSourcesView() }
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

// Keep source masters intact. Select only the habitat panel at runtime and
// cache its full composition; layout never applies an extra aspect-fill crop.
@MainActor
enum HabitatArtworkCache {
    private static let images = NSCache<NSString, UIImage>()
    static func image(for scene: HabitatScene) -> UIImage? {
        let regionKey = scene.artworkRegion.map { "\($0.x),\($0.y),\($0.width),\($0.height)" } ?? "full"
        let key = "\(scene.assetName):\(regionKey)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let source = UIImage(named: scene.assetName) else { return nil }
        let result: UIImage
        if let region = scene.artworkRegion {
            guard region.isValid, let cgImage = source.cgImage else { return nil }
            let rect = CGRect(x: region.x * Double(cgImage.width), y: region.y * Double(cgImage.height),
                width: region.width * Double(cgImage.width), height: region.height * Double(cgImage.height)).integral
            guard CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)).contains(rect),
                  let selected = cgImage.cropping(to: rect) else { return nil }
            result = UIImage(cgImage: selected, scale: source.scale, orientation: .up)
        } else { result = source }
        images.setObject(result, forKey: key)
        return result
    }
}

struct HabitatFooter: View {
    let species: Species
    var body: some View {
        if let scene = HabitatSceneCatalog.primaryScene(for: species), let image = HabitatArtworkCache.image(for: scene) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 160, alignment: .bottom)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
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


struct SpeciesCatalogSourcesView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(SpeciesGuideCatalog.coverageNote)
                    Text("Leefomgevingen: Şekercioğlu en collega's, BIRDBASE v2025.1 (2025), CC BY 4.0. Primaire habitats zijn vertaald naar gedeelde landschapstypen; brede categorieën blijven breed. Automatische bronkoppelingen zijn niet individueel beoordeeld.")
                    Link("BIRDBASE en bronvermelding", destination: URL(string: "https://doi.org/10.6084/m9.figshare.27051040.v1")!)
                    Link("Licentie CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                    Text("AviList Core Team. 2026. AviList: The Global Avian Checklist, v2026. CC BY 4.0.")
                    Link("AviList en bronvermelding", destination: URL(string: "https://doi.org/10.2173/avilist.v2026")!)
                    Text("BirdNET+ Taxonomy v0.5-Nov2026. CC BY-SA 4.0. Nederlandse namen, aliassen en externe soort-ID’s uit deze bron zijn gekoppeld aan de AviList-lijst.")
                    Link("BirdNET+ Taxonomy en broncredits", destination: URL(string: "https://birdnet.cornell.edu/taxonomy/about")!)
                    Text("Bewerkingen: selectie op soortniveau, hoofdletters aangepast, vaste app-ID’s behouden en geluidsherkenning apart gekoppeld. De afgeleide catalogus wordt gedeeld onder CC BY-SA 4.0.")
                    Link("Licentie CC BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    Text("De lijst bevat ook uitgestorven soorten. Eén afwijkende BirdNET-vermelding blijft apart beschikbaar om bestaande detecties en logs te behouden. Ontbrekende Nederlandse namen gebruiken voorlopig de Engelse naam. Illustraties, beschrijvingen en verspreiding worden afzonderlijk aangevuld en gecontroleerd.")
                }.font(FieldGuideTheme.sans(15)).padding(20)
            }.background(FieldGuideTheme.ivory)
                .navigationTitle("Bronnen soortenlijst").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Sluiten") { dismiss() } } }
        }
    }
}
