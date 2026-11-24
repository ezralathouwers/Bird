import SwiftUI
import UIKit
import CoreText

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
struct SpeciesDetailTitleMetrics {
    static func font(size: CGFloat) -> UIFont {
        // Fraunces.ttf defaults to wght=900; SwiftUI SerifText explicitly uses
        // regular. Set its variable axis too when rendering through UIKit.
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(name: "Fraunces-9ptBlack", size: size)
            .addingAttributes([variation: [NSNumber(value: 0x77676874): NSNumber(value: 400)]])
        return UIFont(descriptor: descriptor, size: size)
    }
    static func attributed(_ text: String, size: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = size * 1.02
        paragraph.maximumLineHeight = size * 1.02
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: font(size: size),
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
    var viewportHeight: CGFloat? = nil
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
                        .font(FieldGuideTheme.sans(12.8, relativeTo: .body).weight(.light))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .modifier(BioViewportFade(viewportHeight: viewportHeight))
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
        guard count > 1 else { return nil }
        return ((index + offset) % count + count) % count
    }
    static func slides(available: Set<SpeciesMediaRole>) -> [SpeciesMediaRole] {
        let detail = SpeciesMediaRole.detailSlides.filter { available.contains($0) }
        if !detail.isEmpty { return detail }
        return available.contains(.classic) ? [.classic] : []
    }

}

struct SpeciesArtworkCarousel: UIViewControllerRepresentable {
    let species: Species
    @Binding var page: Int
    var topOverlap: CGFloat = 0

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.view.backgroundColor = .clear
        controller.view.clipsToBounds = true
        // The pager spans the page so tall art can draw behind the header.
        // Slides subtract topOverlap to preserve their original sizing viewport.
        for scroll in controller.view.subviews.compactMap({ $0 as? UIScrollView }) {
            scroll.contentInsetAdjustmentBehavior = .never
        }
        controller.delegate = context.coordinator
        context.coordinator.configure(species: species)
        configureInteraction(controller, coordinator: context.coordinator)
        let selected = min(max(0, page), context.coordinator.controllers.count - 1)
        controller.setViewControllers([context.coordinator.controllers[selected]], direction: .forward, animated: false)
        return controller
    }
    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateTopOverlap(topOverlap)
        if context.coordinator.speciesID != species.id {
            context.coordinator.configure(species: species)
            configureInteraction(controller, coordinator: context.coordinator)
            controller.setViewControllers([context.coordinator.controllers[0]], direction: .forward, animated: false)
        }
    }

    private func configureInteraction(_ controller: UIPageViewController, coordinator: Coordinator) {
        let canSwipe = coordinator.controllers.count > 1
        controller.dataSource = canSwipe ? coordinator : nil
        for scroll in controller.view.subviews.compactMap({ $0 as? UIScrollView }) {
            scroll.isScrollEnabled = canSwipe
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: SpeciesArtworkCarousel
        var speciesID: String?
        var controllers: [UIViewController] = []
        private var topOverlap: CGFloat = 0
        init(_ parent: SpeciesArtworkCarousel) { self.parent = parent }

        func updateTopOverlap(_ value: CGFloat) {
            guard topOverlap != value else { return }
            topOverlap = value
            for case let hosted as UIHostingController<SpeciesArtworkSlide> in controllers {
                var slide = hosted.rootView
                slide.topOverlap = value
                hosted.rootView = slide
            }
        }
        func configure(species: Species) {
            speciesID = species.id
            topOverlap = parent.topOverlap
            let available = Set(SpeciesMediaRole.allCases.filter { UIImage(named: $0.assetName(for: species)) != nil })
            let roles = SpeciesArtworkPaging.slides(available: available)
            let visible: [SpeciesMediaRole] = roles.isEmpty ? [.dynamic] : roles
            controllers = visible.enumerated().map { index, role in
                let controller = UIHostingController(rootView: SpeciesArtworkSlide(species: species, role: role, index: index, totalSlides: visible.count, topOverlap: topOverlap))
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
    static func image(named name: String) async -> UIImage? {
        if let image = images.object(forKey: name as NSString) { return image }
        guard let source = UIImage(named: name) else { return nil }
        guard !Task.isCancelled else { return nil }
        let prominentDynamic = name.hasSuffix("-dynamic") && SpeciesArtworkLayout.dynamicMagnification(speciesID: String(name.dropLast(8))) > 1
        let image = trimmed(source, alphaThreshold: prominentDynamic ? 8 : 0, padding: prominentDynamic ? 24 : 0)
        images.setObject(image, forKey: name as NSString)
        return image
    }
    private static func trimmed(_ source: UIImage, alphaThreshold: UInt8, padding: Int) -> UIImage {
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
            for x in 0..<cg.width where bytes[y * cg.bytesPerRow + x * 4 + offset] > alphaThreshold {
                left = min(left, x); right = max(right, x)
                top = min(top, y); bottom = max(bottom, y)
            }
        }
        guard right >= left, bottom >= top else { return source }
        left = max(0, left - padding); right = min(cg.width - 1, right + padding)
        top = max(0, top - padding); bottom = min(cg.height - 1, bottom + padding)
        guard let crop = cg.cropping(to: CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left + 1), height: CGFloat(bottom - top + 1))) else { return source }
        return UIImage(cgImage: crop, scale: source.scale, orientation: .up)
    }
}

// Size images using the original content viewport below the header; the pager
// itself extends behind the header so existing upward offsets are not clipped.
// Reserve the central navigation button's 32-point protrusion below the image.
enum SpeciesArtworkLayout {
    static let navigationClearance: CGFloat = 32
    static func size(image: CGSize, viewport: CGSize, horizontalBleed: Bool, magnification: CGFloat = 1) -> CGSize {
        guard image.width > 0, image.height > 0 else { return .zero }
        let height = max(0, viewport.height - navigationClearance)
        let fitted = min(viewport.width * (horizontalBleed ? 1.18 : 1) / image.width, height / image.height)
        // Keep the same fitted size on short screens and long titles. Rendering
        // uses a taller canvas so the existing upward offset can cross the header.
        let scale = horizontalBleed && magnification > 1
            ? min(fitted * magnification, max(0, height - 20) / image.height)
            : fitted
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
    static func dynamicMagnification(speciesID: String) -> CGFloat {
        switch speciesID.replacingOccurrences(of: ":", with: "-") {
        case "birdnet-v3-BN03838": 1.9 // Torenvalk: broad hovering composition.
        case "birdnet-v3-BN02626": 1.25 // Roek: reduced after the on-device review.
        case "sample-turdus-merula": 1.4 // Merel.
        default: 1
        }
    }

}

private struct SpeciesArtworkSlide: View {
    let species: Species
    let role: SpeciesMediaRole
    let index: Int
    let totalSlides: Int
    var topOverlap: CGFloat = 0
    @State private var displayImage: UIImage?
    var body: some View {
        GeometryReader { geometry in
            let viewport = CGSize(width: geometry.size.width, height: max(0, geometry.size.height - topOverlap))
            Group {
                if let image = displayImage {
                    // Flight views contain the diagnostic wing tips; fit their
                    // full width rather than bleeding these beyond the screen.
                    let zoom = role == .dynamic ? SpeciesArtworkLayout.dynamicMagnification(speciesID: species.id) : 1
                    let size = SpeciesArtworkLayout.size(image: image.size, viewport: viewport,
                                                         horizontalBleed: role == .dynamic, magnification: zoom)
                    Image(uiImage: image).resizable()
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(x: role == .classic && PrimaryBirdImage.sourceFacesLeft(speciesID: species.id) ? -1 : 1, y: 1)
                        .offset(x: role == .dynamic ? -50 : 0, y: role == .dynamic ? (zoom > 1 ? -10 : -30) : 0)
                        .frame(width: viewport.width,
                               height: max(0, viewport.height - SpeciesArtworkLayout.navigationClearance),
                               alignment: role == .dynamic && zoom == 1 ? .bottom : .center)
                        .accessibilityLabel("\(role.label) van \(species.dutchName), afbeelding \(index + 1) van \(totalSlides)")
                } else if UIImage(named: role.assetName(for: species)) != nil {
                    Color.clear // Existing artwork is preparing; do not call it missing.
                } else {
                    ArtworkPlaceholder(hero: true,
                        accessibilityDescription: "\(role.label) van \(species.dutchName) nog niet beschikbaar",
                        message: role.missingMessage)
                        .padding(20)
                }
            }
            .frame(width: viewport.width, height: viewport.height, alignment: .topLeading)
            .offset(y: topOverlap)
        }
        .background(FieldGuideTheme.ivory)
        .clipped() // Clip at the page edges, never at the tab strip.
        .task(id: role.assetName(for: species)) {
            let loaded = await SpeciesArtworkDisplayCache.image(named: role.assetName(for: species))
            guard !Task.isCancelled else { return }
            displayImage = loaded
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
    private static func key(for scene: HabitatScene) -> String {
        let region = scene.artworkRegion.map { "\($0.x),\($0.y),\($0.width),\($0.height)" } ?? "full"
        return "\(scene.assetName):\(region)"
    }
    static func sourceImage(for scene: HabitatScene) -> UIImage? {
        let cacheKey = (key(for: scene) + ":source") as NSString
        if let cached = images.object(forKey: cacheKey) { return cached }
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
        images.setObject(result, forKey: cacheKey)
        return result
    }
    static func image(for scene: HabitatScene) async -> UIImage? {
        let cacheKey = key(for: scene) as NSString
        if let cached = images.object(forKey: cacheKey) { return cached }
        guard let source = sourceImage(for: scene) else { return nil }
        let result = await ArtworkPaperBackdrop.image(source)
        guard !Task.isCancelled else { return nil }
        images.setObject(result, forKey: cacheKey)
        return result
    }
}

// Size the whole scene from its aspect ratio, then let only its sides bleed.
// Unlike aspect-fill in a fixed-height box, this preserves the treetops/ground.
private struct HabitatBleedLayout: Layout {
    let imageSize: CGSize
    private let widthMultiplier: CGFloat = 1.12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = max(0, proposal.width ?? 320)
        let height = width * widthMultiplier * imageSize.height / max(1, imageSize.width)
        return CGSize(width: width, height: height + SpeciesArtworkLayout.navigationClearance)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let image = subviews.first else { return }
        let width = bounds.width * widthMultiplier
        let height = width * imageSize.height / max(1, imageSize.width)
        image.place(at: CGPoint(x: bounds.midX, y: bounds.maxY - SpeciesArtworkLayout.navigationClearance),
                    anchor: .bottom, proposal: ProposedViewSize(width: width, height: height))
    }
}

struct HabitatFooter: View {
    let species: Species
    @State private var displayImage: UIImage?
    var body: some View {
        Group {
            if let scene = HabitatSceneCatalog.primaryScene(for: species),
               let image = displayImage ?? HabitatArtworkCache.sourceImage(for: scene) {
                HabitatBleedLayout(imageSize: image.size) {
                    Image(uiImage: image).resizable()
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
        }
        .task(id: species.id) {
            guard let scene = HabitatSceneCatalog.primaryScene(for: species) else { return }
            let loaded = await HabitatArtworkCache.image(for: scene)
            guard !Task.isCancelled else { return }
            displayImage = loaded
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
    @ObservedObject private var audioCredits = SpeciesAudioCredits.shared
    var detail: SpeciesDetails? = nil
    @State private var sourceQuery = ""
    @State private var selectedDetail: SpeciesDetails?
    private var shownDetail: SpeciesDetails? { detail ?? selectedDetail }
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            CenteredPageHeader(title: "Bronnen & licenties") { dismiss() }
            if detail == nil {
                BirdTextField("Zoek soort voor brongegevens", text: $sourceQuery)
                    .modifier(RoundedSearchField()).padding(.horizontal, 20).padding(.vertical, 12)
            }
            CatalogResultsScroll(resetKey: sourceQuery) {
                VStack(alignment: .leading, spacing: 20) {
                    if detail == nil {
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
                    if !audioCredits.recordings.isEmpty {
                        Text("Vogelgeluiden").font(FieldGuideTheme.sans(20, relativeTo: .title3))
                        ForEach(audioCredits.recordings.sorted { $0.speciesName < $1.speciesName }) { recording in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(recording.speciesName) — \(recording.artist)")
                                Link("Opname en brongegevens", destination: recording.sourceURL)
                                Link(recording.license, destination: recording.licenseURL)
                            }
                        }
                    }
                    Text("Landen uit coördinaten: Natural Earth 1:10m, publiek domein. Kust- en grensgebieden kunnen afwijken; ontbrekende landen worden waar mogelijk via Apple aangevuld.")
                    Link("Natural Earth en gebruiksvoorwaarden", destination: URL(string: "https://www.naturalearthdata.com/about/terms-of-use/")!)
                    Text("Vlaggen: flag-icons v7.5.0, © 2013 Panayiotis Lipiridis, MIT. Vlakke vlaggen bijgesneden tot cirkels.")
                    Link("flag-icons en licentie", destination: URL(string: "https://github.com/lipis/flag-icons/tree/v7.5.0")!)
                    Text("Fotoherkenning: BioCLIP 2, Imageomics Institute (Gu en collega's, 2025), MIT. Core ML-conversie: fearnt/Thicket. Tekstreferenties: TreeOfLife-200M en Valen-Peregrine/FaunaPulse, CC0; GBIF en Catalogue of Life, CC BY 4.0.")
                    Link("BioCLIP 2 en licentie", destination: URL(string: "https://huggingface.co/imageomics/bioclip-2")!)
                    if let source = try? SpeciesRangeSource.load(), let citation = source.citation {
                        Text(citation)
                        if let license = source.licenseNotice { Text(license) }
                    }
                    Text("Lokale vogelmeldingen: eBird / Cornell Lab of Ornithology en Observation International. De recentste beschikbare melding per soort wordt getoond; datum en tijd zijn lokale waarnemingstijden, soms zonder uur.")
                    Link("eBird", destination: URL(string: "https://ebird.org/")!)
                    Text("Locatiecontext Foto ID: BirdLife-verspreidingskaarten en aanvullende gewone Belgische soorten uit Avibase. Dit is geografische plausibiliteit, geen garantie dat een soort op een exacte plek voorkomt.")
                    Link("Avibase België", destination: URL(string: "https://avibase.bsc-eoc.org/checklist.jsp?region=BE&list=avilist&lang=NL")!)
                    Link("Observation.org", destination: URL(string: "https://observation.org/")!)
                    Link("BirdLife DataZone", destination: URL(string: "https://datazone.birdlife.org/")!)
                }.font(FieldGuideTheme.sans(15)).padding(20)
            }.background(FieldGuideTheme.ivory)
            }.foregroundStyle(FieldGuideTheme.charcoal)
                .background(FieldGuideTheme.ivory.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// Display compositing only: source masters and their review hashes stay intact.
// Flatten the edge-connected light paper to the app's exact ivory; enclosed
// white feathers, bark detail, foliage and the illustration's alpha are kept.
enum ArtworkPaperBackdrop {
    static func normalize(_ pixels: inout [UInt8], width: Int, height: Int) {
        guard width > 0, height > 0, pixels.count == width * height * 4 else { return }
        var visited = [Bool](repeating: false, count: width * height)
        var queue: [Int] = []
        func isPaper(_ index: Int) -> Bool {
            let offset = index * 4
            let r = Int(pixels[offset]), g = Int(pixels[offset + 1]), b = Int(pixels[offset + 2])
            return pixels[offset + 3] == 255 && r >= 230 && g >= 225 && b >= 215
                && abs(r - 245) <= 18 && abs(g - 241) <= 18 && abs(b - 232) <= 18
                && max(r, g, b) - min(r, g, b) <= 25 && r >= g - 3 && g >= b - 3
        }
        func enqueue(_ index: Int) {
            guard !visited[index] else { return }
            visited[index] = true
            if isPaper(index) { queue.append(index) }
        }
        for x in 0..<width { enqueue(x); enqueue((height - 1) * width + x) }
        for y in 0..<height { enqueue(y * width); enqueue(y * width + width - 1) }
        var head = 0
        while head < queue.count {
            let index = queue[head]
            head += 1
            let x = index % width, y = index / width
            if x > 0 { enqueue(index - 1) }
            if x + 1 < width { enqueue(index + 1) }
            if y > 0 { enqueue(index - width) }
            if y + 1 < height { enqueue(index + width) }
        }
        // Match FieldGuideTheme.ivory in the sRGB bitmap used below.
        for index in queue {
            let offset = index * 4
            pixels[offset] = 245; pixels[offset + 1] = 242; pixels[offset + 2] = 235
        }
    }

    @MainActor static func image(_ source: UIImage) async -> UIImage {
        guard let cg = source.cgImage, source.imageOrientation == .up,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return source }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let bitmap = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: bitmap) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return source }
        let input = pixels
        let normalized = await Task.detached(priority: .userInitiated) {
            var output = input
            normalize(&output, width: width, height: height)
            return output
        }.value
        guard !Task.isCancelled else { return source }
        guard let provider = CGDataProvider(data: Data(normalized) as CFData),
              let result = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: bitmap),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return source }
        return UIImage(cgImage: result, scale: source.scale, orientation: .up)
    }
}

private struct BioViewportFade: ViewModifier {
    let viewportHeight: CGFloat?
    func body(content: Content) -> some View {
        if let viewportHeight {
            content.mask {
                GeometryReader { geometry in
                    let height = max(1, geometry.size.height)
                    let cut = viewportHeight - geometry.frame(in: .named("speciesInformationViewport")).minY
                    if cut >= height { Color.black }
                    else if cut <= 0 { Color.clear }
                    else {
                        LinearGradient(stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: max(0, cut - 22) / height),
                            .init(color: .clear, location: cut / height),
                            .init(color: .clear, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    }
                }
            }
        } else { content }
    }
}
