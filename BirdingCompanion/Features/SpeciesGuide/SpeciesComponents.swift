import SwiftUI
import UIKit

enum SpeciesTab: String, CaseIterable {
    case overview = "Overzicht"
    case information = "Informatie", observations = "Waarnemingen"
}

struct SpeciesTabStrip: View {
    @Binding var selection: SpeciesTab
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) { tabs }
            } else {
                HStack(spacing: 0) { tabs }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FieldGuideTheme.charcoal.opacity(0.45), lineWidth: 0.5)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : 5)
        }
    }

    private var tabs: some View {
        ForEach(SpeciesTab.allCases, id: \.self) { tab in
            Button { selection = tab } label: {
                Text(tab.rawValue.uppercased())
                    .font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    .tracking(1.1)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(selection == tab ? FieldGuideTheme.beige : .clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
        }
    }
}

// Explicit baseline spacing matches the tight two-line Dutch title in the
// approved species-page design; tracking remains -0.02 em throughout the app.
private struct SpeciesDetailTitleMetrics {
    static func attributed(_ text: String, size: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = size * 1.02
        paragraph.maximumLineHeight = size * 1.02
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: UIFont(name: "Fraunces-9ptBlack", size: size) ?? .systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: UIColor(FieldGuideTheme.charcoal),
            .kern: size * -0.02,
            .paragraphStyle: paragraph
        ])
    }
}

struct SpeciesDetailTitle: UIViewRepresentable {
    let text: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 34

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.isAccessibilityElement = true
        label.accessibilityTraits = [.header, .staticText]
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = SpeciesDetailTitleMetrics.attributed(text, size: size)
        label.accessibilityLabel = text
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
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

// Native page transitions wrap in either direction. Unlike duplicate sentinel
// pages, this needs no delayed index reset at the end of a swipe.
enum SpeciesArtworkPaging {
    static func index(after index: Int, offset: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        return ((index + offset) % count + count) % count
    }
}

struct SpeciesArtworkCarousel: UIViewControllerRepresentable {
    let species: Species
    @Binding var page: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.view.backgroundColor = .clear
        controller.view.clipsToBounds = true
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        context.coordinator.configure(species: species)
        controller.setViewControllers([context.coordinator.controllers[page]], direction: .forward, animated: false)
        return controller
    }
    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.speciesID != species.id {
            context.coordinator.configure(species: species)
            controller.setViewControllers([context.coordinator.controllers[0]], direction: .forward, animated: false)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: SpeciesArtworkCarousel
        var speciesID: String?
        var controllers: [UIViewController] = []
        init(_ parent: SpeciesArtworkCarousel) { self.parent = parent }

        func configure(species: Species) {
            speciesID = species.id
            controllers = SpeciesMediaRole.detailSlides.enumerated().map { index, role in
                let controller = UIHostingController(rootView: SpeciesArtworkSlide(species: species, role: role, index: index))
                controller.view.backgroundColor = .clear
                controller.safeAreaRegions = []
                return controller
            }
        }
        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            adjacent(to: viewController, offset: -1)
        }
        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            adjacent(to: viewController, offset: 1)
        }
        private func adjacent(to controller: UIViewController, offset: Int) -> UIViewController? {
            guard let current = controllers.firstIndex(where: { $0 === controller }),
                  let next = SpeciesArtworkPaging.index(after: current, offset: offset, count: controllers.count) else { return nil }
            return controllers[next]
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let visible = pageViewController.viewControllers?.first,
                  let index = controllers.firstIndex(where: { $0 === visible }) else { return }
            parent.page = index
        }
    }
}

// Display-only trim of empty PNG margins makes the bird/scene meet the bottom
// edge. Source masters and artwork-manifest hashes remain untouched.
@MainActor
private enum SpeciesArtworkDisplayCache {
    private static let images = NSCache<NSString, UIImage>()
    static func image(named name: String) -> UIImage? {
        if let image = images.object(forKey: name as NSString) { return image }
        guard let source = UIImage(named: name) else { return nil }
        let image = trimmed(source)
        images.setObject(image, forKey: name as NSString)
        return image
    }
    private static func trimmed(_ source: UIImage) -> UIImage {
        guard let cg = source.cgImage, source.imageOrientation == .up,
              cg.bitsPerPixel == 32, cg.bitsPerComponent == 8,
              let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data),
              CFDataGetLength(data) >= cg.bytesPerRow * cg.height else { return source }
        let alpha: Int
        switch cg.alphaInfo {
        case .first, .premultipliedFirst: alpha = 0
        case .last, .premultipliedLast: alpha = 3
        default: return source
        }
        let offset = cg.bitmapInfo.contains(.byteOrder32Little) ? 3 - alpha : alpha
        var left = cg.width, right = -1, top = cg.height, bottom = -1
        for y in 0..<cg.height {
            for x in 0..<cg.width where bytes[y * cg.bytesPerRow + x * 4 + offset] > 0 {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard right >= left, bottom >= top,
              let crop = cg.cropping(to: CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left + 1), height: CGFloat(bottom - top + 1))) else { return source }
        return UIImage(cgImage: crop, scale: source.scale, orientation: .up)
    }
}

private struct SpeciesArtworkSlide: View {
    let species: Species
    let role: SpeciesMediaRole
    let index: Int
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = SpeciesArtworkDisplayCache.image(named: role.assetName(for: species)) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(width: geometry.size.width * 1.18, height: geometry.size.height, alignment: .bottom)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
                        .clipped()
                        .accessibilityLabel("\(role.label) van \(species.dutchName), afbeelding \(index + 1) van 4")
                } else {
                    ArtworkPlaceholder(hero: true,
                        accessibilityDescription: "\(role.label) van \(species.dutchName) nog niet beschikbaar",
                        message: role.missingMessage)
                        .padding(20)
                }
            }
        }
        .background(FieldGuideTheme.ivory)
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
                        TextField("Zoek soort voor brongegevens", text: $sourceQuery).modifier(RoundedSearchField())
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
                            if span.isEstimated {
                                Text(span.method == "estimated-wingspan-game" ? "Spanwijdte: schatting op basis van de numerieke Wingspan-kaartwaarde via Wingsearch. Sommige kaartwaarden zijn geëxtrapoleerd; de dataset vermeldt dit niet per kaart." : "Spanwijdte: modelschatting van Fox en collega's (2026), CC BY 4.0. Het geschatte middenpunt wordt getoond, zonder berekende grenzen als gemeten bereik voor te stellen.")
                            } else {
                                Text("Spanwijdte: \(span.method == "reported" ? "gerapporteerde meetgegevens, Fox en collega's (2026), CC BY 4.0" : "gerapporteerde waarde uit de vermelde bron"). Waarden kunnen per bron, populatie en meetmethode verschillen.")
                            }
                            Link("Bron spanwijdte", destination: span.sourceURL)
                            if span.method == "source-reported-wikidata" {
                                Text("Wikidata, CC0. Afzonderlijke gerapporteerde waarde met bronverwijzing; geen afgeleid minimum of maximum.")
                            }
                            if span.sourceURL.host?.hasSuffix(".wikipedia.org") == true {
                                Text("Wikipedia-bijdragers, CC BY-SA 4.0. Numerieke waarde overgenomen en omgerekend naar centimeter.")
                                Link("Wikipedia-bijdragers spanwijdte", destination: span.sourceURL.appending(queryItems: [URLQueryItem(name: "action", value: "history")]))
                            }
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
