import SwiftUI
import MapKit
@preconcurrency import UIKit

struct FirstObservationMapProjection {
    static func records(_ observations: [Observation]) -> [Observation] {
        var first: [String: Observation] = [:]
        for log in observations {
            if let previous = first[log.speciesID], previous.observedAt < log.observedAt ||
                (previous.observedAt == log.observedAt && previous.id.uuidString < log.id.uuidString) { continue }
            first[log.speciesID] = log
        }
        return first.values.filter { log in
            guard let lat = log.latitude, let lon = log.longitude else { return false }
            return lat.isFinite && lon.isFinite && (-90...90).contains(lat) && (-180...180).contains(lon) && (lat != 0 || lon != 0)
        }.sorted { $0.speciesID < $1.speciesID }
    }
}

struct FirstObservationsMapView: View {
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var connectivity = MapConnectivity()
    @State private var selected: Observation?
    @State private var cluster: [Observation] = []
    @State private var showCluster = false
    @State private var queuedSelection: Observation?
    // nil preserves the original first-log-per-species country overview.
    var observations: [Observation]? = nil
    var mapTitle = "Logboekkaart"
    private var records: [Observation] {
        if let observations {
            return observations.filter { log in
                guard let lat = log.latitude, let lon = log.longitude else { return false }
                return lat.isFinite && lon.isFinite && (-90...90).contains(lat) && (-180...180).contains(lon) && (lat != 0 || lon != 0)
            }
        }
        return FirstObservationMapProjection.records(store.observations)
    }
    var body: some View {
        ZStack {
            FirstObservationNativeMap(records: records, selectCluster: { cluster = $0; showCluster = true }) { selected = $0 }
                .ignoresSafeArea()
        }
            .overlay(alignment: .topTrailing) {
                MapCloseButton(label: "Sluit \(mapTitle)") { dismiss() }.padding(.trailing, 20).padding(.top, 12)
            }
            .overlay(alignment: .bottom) {
                if connectivity.isOffline {
                    Text("Offline: de basiskaart kan onvolledig zijn. Je opgeslagen plekken blijven beschikbaar.")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote)).padding(12)
                        .background(FieldGuideTheme.ivory, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
            .overlay {
                if records.isEmpty { Text("Geen waarnemingsplekken beschikbaar.").padding(20).background(FieldGuideTheme.ivory, in: RoundedRectangle(cornerRadius: 16)).padding(20) }
            }
            .sheet(isPresented: $showCluster, onDismiss: {
                if let log = queuedSelection { queuedSelection = nil; selected = log }
            }) {
                VStack(spacing: 0) {
                    CenteredPageHeader(title: "Vogels op deze plek") { showCluster = false }
                    CatalogResultsScroll(resetKey: "cluster") {
                        LazyVStack(spacing: 0) {
                            ForEach(cluster.sorted { SessionStats.bird($0.speciesID).dutchName.localizedStandardCompare(SessionStats.bird($1.speciesID).dutchName) == .orderedAscending }) { log in
                                let species = SessionStats.bird(log.speciesID)
                                Button { queuedSelection = log; showCluster = false } label: {
                                    HStack(spacing: 12) {
                                        PrimaryBirdArtwork(species: species).frame(width: 64, height: 64)
                                        VStack(alignment: .leading, spacing: 4) {
                                            SerifText(species.dutchName, size: 18, relativeTo: .body)
                                            Text(species.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }.padding(.vertical, 6).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Divider()
                            }
                        }.padding(.horizontal, 20).padding(.bottom, 24)
                    }
                }.foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory)
                    .presentationDetents([.medium, .large])
            }
            .fullScreenCover(item: $selected) { log in
                ObservationMapView(observation: log, species: SessionStats.bird(log.speciesID))
            }
    }
}

private final class FirstMapAnnotation: NSObject, MKAnnotation {
    let log: Observation
    let coordinate: CLLocationCoordinate2D
    var title: String? { SessionStats.bird(log.speciesID).dutchName }
    init(_ log: Observation) {
        self.log = log
        coordinate = CLLocationCoordinate2D(latitude: log.latitude!, longitude: log.longitude!)
    }
}

private struct FirstObservationNativeMap: UIViewRepresentable {
    let records: [Observation]
    let selectCluster: ([Observation]) -> Void
    let select: (Observation) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> MKMapView {
        let view = MKMapView()
        view.overrideUserInterfaceStyle = .light
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        view.preferredConfiguration = configuration
        view.delegate = context.coordinator
        view.showsUserLocation = false
        view.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: "first-bird")
        view.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: "first-cluster")
        context.coordinator.update(view, records: records)
        return view
    }
    func updateUIView(_ view: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(view, records: records)
    }
    @MainActor final class Coordinator: NSObject, @preconcurrency MKMapViewDelegate {
        var parent: FirstObservationNativeMap
        private var keys = Set<String>()
        private var framed = false
        private let thumbnails = NSCache<NSString, UIImage>()
        private struct ThumbnailJob {
            let species: Species
            weak var view: MKAnnotationView?
            weak var annotation: FirstMapAnnotation?
        }
        private var thumbnailJobs: [ThumbnailJob] = []
        private var preparingThumbnail = false
        init(_ parent: FirstObservationNativeMap) {
            self.parent = parent
            thumbnails.countLimit = 100
            thumbnails.totalCostLimit = 4 * 96 * 96 * 100
        }
        func update(_ view: MKMapView, records: [Observation]) {
            let newKeys = Set(records.map { "\($0.id)-\($0.latitude ?? 0)-\($0.longitude ?? 0)" })
            guard newKeys != keys else { return }
            keys = newKeys
            view.removeAnnotations(view.annotations)
            let annotations = records.map(FirstMapAnnotation.init)
            view.addAnnotations(annotations)
            if !framed && !annotations.isEmpty {
                view.showAnnotations(annotations, animated: false)
                framed = true
            }
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: "first-cluster", for: cluster)
                view.image = marker(image: nil, count: cluster.memberAnnotations.count)
                view.collisionMode = .circle
                view.displayPriority = .required
                return view
            }
            guard let bird = annotation as? FirstMapAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "first-bird", for: bird)
            view.clusteringIdentifier = "first-species-locations"
            view.collisionMode = .circle
            view.canShowCallout = false
            let species = SessionStats.bird(bird.log.speciesID)
            let key = species.id as NSString
            view.image = marker(image: thumbnails.object(forKey: key))
            view.accessibilityLabel = "\(species.dutchName), waarnemingsplek"
            if thumbnails.object(forKey: key) == nil {
                thumbnailJobs.append(ThumbnailJob(species: species, view: view, annotation: bird))
                prepareNextThumbnail()
            }
            return view
        }
        private func prepareNextThumbnail() {
            guard !preparingThumbnail else { return }
            preparingThumbnail = true
            Task { [weak self] in
                guard let self else { return }
                defer { preparingThumbnail = false }
                while !thumbnailJobs.isEmpty {
                    let job = thumbnailJobs.removeFirst()
                    guard let view = job.view, let annotation = job.annotation, view.annotation === annotation else { continue }
                    let key = job.species.id as NSString
                    if let cached = thumbnails.object(forKey: key) { view.image = marker(image: cached); continue }
                    guard let source = UIImage(named: SpeciesMediaRole.classic.assetName(for: job.species)),
                          let thumbnail = await source.byPreparingThumbnail(ofSize: CGSize(width: 96, height: 96)) else { continue }
                    let image = PrimaryBirdImage.sourceFacesLeft(speciesID: job.species.id) ? thumbnail.withHorizontallyFlippedOrientation() : thumbnail
                    thumbnails.setObject(image, forKey: key, cost: 96 * 96 * 4)
                    if view.annotation === annotation { view.image = marker(image: image) }
                }
            }
        }
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                let members = cluster.memberAnnotations.compactMap { $0 as? FirstMapAnnotation }
                let samePoint = members.first.map { first in members.allSatisfy { $0.coordinate.latitude == first.coordinate.latitude && $0.coordinate.longitude == first.coordinate.longitude } } ?? false
                if samePoint || (mapView.region.span.latitudeDelta < 0.001 && mapView.region.span.longitudeDelta < 0.001) {
                    parent.selectCluster(members.map(\.log))
                } else { mapView.showAnnotations(cluster.memberAnnotations, animated: true) }
            } else if let annotation = view.annotation as? FirstMapAnnotation { parent.select(annotation.log) }
            if let annotation = view.annotation { mapView.deselectAnnotation(annotation, animated: false) }
        }
        private func marker(image: UIImage?, count: Int? = nil) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 72, height: 72)).image { _ in
                let circle = UIBezierPath(ovalIn: CGRect(x: 0.5, y: 0.5, width: 71, height: 71))
                UIColor(count == nil ? FieldGuideTheme.ivory : FieldGuideTheme.charcoal).setFill(); circle.fill()
                UIColor(FieldGuideTheme.taupe).setStroke(); circle.lineWidth = 1; circle.stroke()
                if let count {
                    let text = String(count) as NSString
                    let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor(FieldGuideTheme.ivory)]
                    let size = text.size(withAttributes: attributes)
                    text.draw(at: CGPoint(x: (72 - size.width) / 2, y: (72 - size.height) / 2), withAttributes: attributes)
                } else if let image {
                    let scale = min(48 / image.size.width, 48 / image.size.height)
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    image.draw(in: CGRect(x: (72 - size.width) / 2, y: (72 - size.height) / 2, width: size.width, height: size.height))
                } else {
                    UIImage(systemName: "bird")?.withTintColor(UIColor(FieldGuideTheme.charcoal), renderingMode: .alwaysOriginal)
                        .draw(in: CGRect(x: 22, y: 22, width: 28, height: 28))
                }
            }
        }
    }
}
