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
    private var detail: SpeciesDetails? { SpeciesDetailsCatalog.details(for: species.id) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = SpeciesDetailsCatalog.loadError {
                Text(error).font(FieldGuideTheme.sans(16, relativeTo: .body))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let span = detail?.wingspan {
                        factRow(SpeciesFact(id: "Spanwijdte", symbol: nil, value: span.displayValue))
                    }
                    if let bio = detail?.bio {
                    Text(bio)
                        .font(FieldGuideTheme.sans(16, relativeTo: .body).weight(.light))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                    }
                }
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
    var detail: SpeciesDetails? = nil
    @State private var sourceQuery = ""
    @State private var selectedDetail: SpeciesDetails?
    private var shownDetail: SpeciesDetails? { detail ?? selectedDetail }
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if detail == nil {
                        Text("Bronnen en licenties").font(FieldGuideTheme.sans(24, relativeTo: .title2))
                        TextField("Zoek soort voor brongegevens", text: $sourceQuery).textFieldStyle(.roundedBorder)
                        if !sourceQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ForEach(Array(SpeciesCatalogSearch.results(for: sourceQuery, in: SpeciesGuideCatalog.species).prefix(20))) { species in
                                Button(species.dutchName) {
                                    selectedDetail = SpeciesDetailsCatalog.details(for: species.id)
                                    sourceQuery = ""
                                }.frame(minHeight: 44)
                            }
                        }
                    }
                    if let detail = shownDetail {
                        Text(SpeciesGuideCatalog.species(id: detail.speciesID)?.dutchName ?? detail.scientificName)
                            .font(FieldGuideTheme.sans(20, relativeTo: .title3))
                        if detail.bioMethod == "wikipedia-nl-excerpt" {
                            Text("Beschrijving: kort, ongewijzigd fragment uit Nederlandstalige Wikipedia via BirdNET+ Taxonomy. Wikipedia-bijdragers, CC BY-SA 4.0. Alleen teksten met Wikipedia als bron zijn overgenomen; geen automatisch vertaalde of gegenereerde teksten uit die bron.")
                        } else if detail.bioMethod == "birdbase-habitat-diet" {
                            Text("Beschrijving: korte Nederlandse tekst samengesteld uit de primaire habitat- en voedselcategorieën van BIRDBASE v2025.1. Dit is een algemene ecologische beschrijving, geen individueel geschreven veldgidsartikel.")
                        } else if detail.bioMethod == "source-summary-nl" {
                            Text("Beschrijving: korte Nederlandse samenvatting op basis van de vermelde bronnen. Bewerkingen van Wikipedia vallen onder CC BY-SA 4.0, met naamsvermelding van Wikipedia-bijdragers.")
                        }
                        ForEach(detail.bioSourceURLs, id: \.self) { url in
                            Link(url.host ?? "Bron beschrijving", destination: url)
                        }
                        if let wiki = detail.bioSourceURLs.first(where: { $0.host?.hasSuffix(".wikipedia.org") == true }) {
                            Link("Wikipedia-bijdragers en bewerkingsgeschiedenis", destination: wiki.appending(queryItems: [URLQueryItem(name: "action", value: "history")]))
                        }
                        if let span = detail.wingspan {
                            Text("Spanwijdte: \(span.method == "reported" ? "gerapporteerde meetgegevens, Fox en collega's (2026), CC BY 4.0" : "gecontroleerde vogelgidswaarde uit de vermelde bron"). Waarden kunnen per bron, populatie en meetmethode verschillen.")
                            Link("Bron spanwijdte", destination: span.sourceURL)
                        }
                    }
                    Text("Leefomgevingen: Şekercioğlu en collega's, BIRDBASE v2025.1 (2025), CC BY 4.0. Primaire habitats zijn vertaald naar gedeelde landschapstypen; brede categorieën blijven breed. Automatische bronkoppelingen zijn niet individueel beoordeeld.")
                    Link("BIRDBASE en bronvermelding", destination: URL(string: "https://doi.org/10.6084/m9.figshare.27051040.v1")!)
                    Link("Licentie CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                    Text("AviList Core Team. 2026. AviList: The Global Avian Checklist, v2026. CC BY 4.0.")
                    Link("AviList en bronvermelding", destination: URL(string: "https://doi.org/10.2173/avilist.v2026")!)
                    Text("BirdNET+ Taxonomy v0.5-Nov2026. CC BY-SA 4.0. Nederlandse namen, aliassen en externe soort-ID’s uit deze bron zijn gekoppeld aan de AviList-lijst.")
                    Link("BirdNET+ Taxonomy en broncredits", destination: URL(string: "https://birdnet.cornell.edu/taxonomy/about")!)
                    Text("Bewerkingen: selectie op soortniveau, hoofdletters aangepast, vaste app-ID’s behouden en geluidsherkenning apart gekoppeld. De afgeleide catalogus wordt gedeeld onder CC BY-SA 4.0.")
                    Link("Licentie CC BY-SA 4.0", destination: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!)
                    Text("Fotoherkenning: BioCLIP 2, Imageomics Institute (Gu en collega's, 2025), MIT. Core ML-conversie: fearnt/Thicket. Tekstreferenties: TreeOfLife-200M en Valen-Peregrine/FaunaPulse, CC0; GBIF en Catalogue of Life, CC BY 4.0.")
                    Link("BioCLIP 2 en licentie", destination: URL(string: "https://huggingface.co/imageomics/bioclip-2")!)
                    Text("Verspreidingsgegevens: BirdLife International DataZone. Gebruik volgens de verleende toestemming.")
                    Link("BirdLife DataZone", destination: URL(string: "https://datazone.birdlife.org/")!)
                }.font(FieldGuideTheme.sans(15)).padding(20)
            }.background(FieldGuideTheme.ivory)
                .navigationTitle("Info").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Sluiten") { dismiss() } } }
        }
    }
}
