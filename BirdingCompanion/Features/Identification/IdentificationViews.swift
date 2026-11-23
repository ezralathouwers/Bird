import SwiftUI
import PhotosUI
@preconcurrency import AVFoundation

enum IdentificationRoute: Hashable { case photo, audio }

struct IdentificationView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                IdentificationOptionsLayout(viewportHeight: max(0, geometry.size.height - 97)) {
                    PageHeading(text: "Identificeer").accessibilityAddTraits(.isHeader)
                    NavigationLink(value: IdentificationRoute.photo) {
                        option("Foto", detail: "Maak of kies een foto", photo: true)
                    }
                    NavigationLink(value: IdentificationRoute.audio) {
                        option("Audio", detail: "Luister naar vogels om je heen", photo: false)
                    }
                }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 77)
            }
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
    }
    private func option(_ name: String, detail: String, photo: Bool) -> some View {
        HStack(spacing: 20) {
            Group {
                if photo { CameraOutlineMark().stroke(style: FieldGuideTheme.navigationStroke).frame(width: 36, height: 36) }
                else { Image(systemName: "waveform").font(.system(size: 36, weight: .ultraLight)) }
            }.frame(width: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(FieldGuideTheme.sans(24, relativeTo: .title2))
                Text(detail).font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
        }.padding(24).frame(minHeight: 148, maxHeight: .infinity)
            .foregroundStyle(FieldGuideTheme.charcoal)
            .background(FieldGuideTheme.beige.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct IdentificationOptionsLayout: Layout {
    let viewportHeight: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let width = max(0, proposal.width ?? 320)
        let heading = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        let minimumCard = max(148, subviews.dropFirst().map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 148)
        return CGSize(width: width, height: max(viewportHeight, heading + 18 + 16 + 2 * minimumCard))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let heading = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        let minimumCard = max(148, subviews.dropFirst().map { $0.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height }.max() ?? 148)
        let card = max(minimumCard, (bounds.height - heading - 18 - 16) / 2)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: heading))
        for index in 1...2 {
            subviews[index].place(at: CGPoint(x: bounds.minX, y: bounds.minY + heading + 18 + CGFloat(index - 1) * (card + 16)),
                                 anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: card))
        }
    }
}

struct SoundIdentificationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: SoundIdentificationModel
    @EnvironmentObject private var pins: SoundResultPins
    @State private var selectedSpecies: Species?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: model.isRecording ? "mic.fill" : "mic")
                    Text(model.isStarting ? "Opname voorbereiden" : model.isRecording ? "Aan het luisteren" : "Opname gestopt").font(FieldGuideTheme.sans(20, relativeTo: .title3))
                    Spacer()
                    if model.isRecording, let startedAt = model.startedAt {
                        Text(startedAt, style: .timer).monospacedDigit()
                    } else { Text(Self.elapsed(model.duration)).monospacedDigit() }
                }
                CompactSonogram(columns: model.columns).frame(height: 120)
                HStack(spacing: 16) {
                    Button {
                        if model.isRecording { Task { await model.finishAndIdentify() } }
                        else { model.begin() }
                    } label: {
                        Label(model.isRecording ? "Stop opname" : "Opnemen", systemImage: model.isRecording ? "stop.fill" : "mic")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }.foregroundStyle(FieldGuideTheme.ivory).background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius, style: .continuous))
                        .disabled(model.isStarting || model.isIdentifying)

                }
                if model.isStarting { ProgressView("Geluid-ID voorbereiden…") }
                if model.isIdentifying { ProgressView("Opname analyseren…") }
                Text("Mogelijke vogels").font(FieldGuideTheme.sans(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                if let message = model.message { Text(message).font(FieldGuideTheme.sans(14, relativeTo: .subheadline)) }
                if let message = pins.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    SoundIdentificationResults(candidates: model.candidates, pins: pins,
                        activeIDs: model.activity.activeIDs(at: context.date, recording: model.isRecording)) { selectedSpecies = $0 }
                }
            }.padding(20).padding(.bottom, 79)
        }.safeAreaInset(edge: .top, spacing: 0) {
            CenteredPageHeader(title: "Audio ID") { dismiss() }.background(FieldGuideTheme.ivory)
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .onAppear { if model.startedAt == nil { model.begin() } }
            .navigationDestination(item: $selectedSpecies) { bird in SpeciesDetailView(species: bird) }
    }
    private static func elapsed(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value)); return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct CompactSonogram: View {
    let columns: [[Float]]
    var body: some View {
        Canvas { context, size in
            let columnWidth = size.width / 100
            for (x, column) in columns.enumerated() {
                let rowHeight = size.height / CGFloat(max(1, column.count))
                for (y, intensity) in column.enumerated() {
                    let rect = CGRect(x: CGFloat(x) * columnWidth,
                        y: size.height - CGFloat(y + 1) * rowHeight, width: columnWidth + 0.5, height: rowHeight + 0.5)
                    context.fill(Path(rect), with: .color(FieldGuideTheme.charcoal.opacity(Double(intensity))))
                }
            }
        }.background(FieldGuideTheme.beige.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Live sonogram van de microfoon, lage frequenties onderaan en hoge bovenaan")
    }
}

struct PhotoIdentificationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PhotoIdentificationModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var importing = false
    @State private var error: String?
    @State private var cameraPhoto: Data?
    @State private var crop: PhotoCropSelection?
    @State private var recognitionTask: Task<Void, Never>?
    @State private var selectedSpecies: Species?
    @State private var location: PhotoLocationSelection?
    @State private var showLocation = false
    @State private var rangeStatus: [String: PhotoRangeLikelihood] = [:]
    @State private var checkingLocation = false
    private var contextKey: String {
        "\(location?.latitude ?? 999),\(location?.longitude ?? 999):" + model.candidates.map(\.id).joined(separator: ",")
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Button { Task { await openCamera() } } label: {
                        HStack { CameraOutlineMark().stroke(style: FieldGuideTheme.navigationStroke).frame(width: 24, height: 24); Text("Maak foto") }.frame(maxWidth: .infinity, minHeight: 52)
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        HStack { Image(systemName: "photo").font(.system(size: 20.7, weight: .ultraLight)); Text("Kies foto") }.frame(maxWidth: .infinity, minHeight: 52)
                    }
                }.buttonStyle(PhotoChoiceStyle())
                if let data = model.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityLabel("Geselecteerde vogelfoto")
                        .overlay { if model.isLoading { ProgressView("Foto analyseren…").padding(16).background(FieldGuideTheme.beige, in: RoundedRectangle(cornerRadius: 14)) } }
                        .padding(.bottom, -12)
                } else {
                    RoundedRectangle(cornerRadius: 16).fill(FieldGuideTheme.beige.opacity(0.22)).frame(height: 240)
                        .overlay { NavigationOutlineMark(kind: .bird).stroke(style: FieldGuideTheme.navigationStroke).frame(width: 48, height: 48).foregroundStyle(FieldGuideTheme.taupe).accessibilityLabel("Kies een vogelfoto") }
                }
                if importing { ProgressView("Foto openen…") }
                if model.photo != nil {
                    if let location {
                        PhotoLocationBadge(name: location.name, edit: { showLocation = true })
                    } else {
                        Button("Locatie toevoegen") { showLocation = true }.buttonStyle(PhotoChoiceStyle())
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
                if let message = model.message { Text(message).font(FieldGuideTheme.sans(14, relativeTo: .subheadline)) }
                Text("Mogelijke vogels").font(FieldGuideTheme.sans(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                if model.photo == nil { Text("Maak of kies een foto om herkenningssuggesties te bekijken.") }
                VStack(spacing: 4) {
                    if location != nil && checkingLocation {
                        ProgressView("Verspreiding controleren…")
                    } else if location != nil {
                        photoGroup("Waarschijnlijk op deze locatie", likelihood: .likely)
                        photoGroup("Onwaarschijnlijk op deze locatie", likelihood: .unlikely)
                        photoGroup("Geen verspreidingsgegevens beschikbaar", likelihood: .unknown)
                    } else { IdentificationResults(candidates: model.candidates) { selectedSpecies = $0 } }
                }
            }.padding(20).padding(.bottom, 104)
        }.safeAreaInset(edge: .top, spacing: 0) {
            CenteredPageHeader(title: "Foto ID") { dismiss() }.background(FieldGuideTheme.ivory)
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                model.clear(); error = nil; importing = true
                defer { importing = false }
                do {
                    let loaded = try await selectedPhoto.loadTransferable(type: Data.self)
                    guard !Task.isCancelled else { return }
                    guard let data = loaded, data.count <= 20 * 1024 * 1024,
                          UIImage(data: data) != nil else { throw IdentificationError.invalidPhoto }
                    crop = PhotoCropSelection(data: data)
                    self.selectedPhoto = nil // Consume the import; returning from a cover must not reopen cropping.
                } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            }
            .sheet(isPresented: $showCamera, onDismiss: {
                if let data = cameraPhoto { cameraPhoto = nil; crop = PhotoCropSelection(data: data) }
            }) {
                CameraCapture { data in
                    showCamera = false; selectedPhoto = nil
                    guard let data else { return }
                    error = nil
                    cameraPhoto = data
                }
            }
            .fullScreenCover(item: $crop) { selection in
                PhotoCropView(data: selection.data, location: location) { data, chosenLocation in
                    location = chosenLocation
                    crop = nil
                    guard let data else { return }
                    recognitionTask?.cancel()
                    recognitionTask = Task { await model.identify(data) }
                }
            }
            .onDisappear { recognitionTask?.cancel(); model.cancel() }
            .sheet(isPresented: $showLocation) { PhotoLocationPicker(selection: location) { location = $0 } }
            .task(id: contextKey) {
                rangeStatus = [:]; checkingLocation = false
                guard let location else { return }
                checkingLocation = true
                let statuses = await PhotoRangeContext.classify(model.candidates, at: location)
                guard !Task.isCancelled else { return }
                rangeStatus = statuses; checkingLocation = false
            }
            .navigationDestination(item: $selectedSpecies) { bird in SpeciesDetailView(species: bird) }
    }
    @ViewBuilder private func photoGroup(_ title: String, likelihood: PhotoRangeLikelihood) -> some View {
        let birds = model.candidates.filter { (rangeStatus[$0.id] ?? .unknown) == likelihood }
        if !birds.isEmpty {
            Text(title).font(FieldGuideTheme.sans(15, relativeTo: .subheadline)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, likelihood == .unlikely ? 22 : 12)
            IdentificationResults(candidates: birds) { selectedSpecies = $0 }
        }
    }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { error = "Op dit apparaat is geen camera beschikbaar. Je kunt een foto kiezen."; return }
        guard await AVCaptureDevice.requestAccess(for: .video) else { error = "Sta cameratoegang toe in Instellingen, of kies een bestaande foto."; return }
        showCamera = true
    }
}

private struct CameraCapture: UIViewControllerRepresentable {
    var completion: (Data?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController(); controller.sourceType = .camera
        controller.cameraCaptureMode = .photo; controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    @MainActor final class Coordinator: NSObject, @preconcurrency UIImagePickerControllerDelegate, @preconcurrency UINavigationControllerDelegate {
        let completion: (Data?) -> Void
        init(completion: @escaping (Data?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
        }
    }
}

private struct SoundIdentificationResults: View {
    let candidates: [IdentificationCandidate]
    @ObservedObject var pins: SoundResultPins
    var activeIDs: Set<String> = []
    var open: (Species) -> Void
    var body: some View {
        let rows = SoundResultOrdering.rows(candidates: candidates, pins: pins.species)
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 16) {
                    PrimaryBirdArtwork(species: row.species).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            SerifText(row.species.dutchName, size: 18, relativeTo: .body)
                            if row.isPinned {
                                Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(FieldGuideTheme.khaki)
                            }
                        }
                        Text(row.species.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
                }
                .frame(minHeight: 64).padding(.horizontal, 12).padding(.vertical, 1)
                .background(activeIDs.contains(row.id) ? FieldGuideTheme.beige.opacity(0.4) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12))
                .animation(.easeOut(duration: 0.35), value: activeIDs.contains(row.id))
                .contentShape(Rectangle())
                .gesture(TapGesture(count: 2).exclusively(before: TapGesture(count: 1)).onEnded { action in
                    switch action {
                    case .first: pins.toggle(row.species)
                    case .second: open(row.species)
                    }
                })
                .onLongPressGesture(minimumDuration: 0.5) { pins.toggle(row.species) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(row.species.dutchName), \(row.species.englishDisplayName)\(row.isPinned ? ", vastgezet" : "")\(activeIDs.contains(row.id) ? ", nu gehoord" : "")")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opent de soortpagina. Houd ingedrukt om vast te zetten of los te maken.")
                .accessibilityAction { open(row.species) }
                .accessibilityAction(named: Text(row.isPinned ? "Losmaken" : "Vastzetten")) { pins.toggle(row.species) }
                if row.id != rows.last?.id { Divider() }
            }
        }
    }
}

private struct IdentificationResults: View {
    let candidates: [IdentificationCandidate]
    let open: (Species) -> Void
    var body: some View {
        ForEach(candidates) { candidate in
            Button { open(candidate.species) } label: {
                HStack(spacing: 16) {
                    PrimaryBirdArtwork(species: candidate.species).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        SerifText(candidate.species.dutchName, size: 18, relativeTo: .body)
                        Text(candidate.species.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
                }.frame(minHeight: 64).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Divider()
        }

    }
}

private struct PhotoChoiceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(FieldGuideTheme.charcoal)
            .background(FieldGuideTheme.beige.opacity(configuration.isPressed ? 0.9 : 0.6),
                        in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
    }
}

struct PhotoLocationPicker: View {
    let selection: PhotoLocationSelection?
    let save: (PhotoLocationSelection?) -> Void
    @StateObject private var location = ObservationLocationModel(locationPolicy: .browsing)
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 16) {
            CenteredPageHeader(title: "Fotolocatie") { dismiss() }
            ObservationLocationPicker(location: location).clipShape(RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 20)
            Button("Gebruik huidige locatie") { location.useCurrentLocation() }
            if location.isLocating || location.isNaming { ProgressView() }
            if let message = location.message { Text(message).font(FieldGuideTheme.sans(14)).padding(.horizontal, 20) }
            Button("Locatie gebruiken") {
                guard let latitude = location.latitude, let longitude = location.longitude else { return }
                save(PhotoLocationSelection(latitude: latitude, longitude: longitude,
                    name: location.locationName.isEmpty ? String(format: "%.3f, %.3f", latitude, longitude) : location.locationName))
                dismiss()
            }.buttonStyle(PhotoChoiceStyle()).padding(.horizontal, 20).disabled(location.latitude == nil)
            if selection != nil { Button("Locatie verwijderen") { save(nil); dismiss() } }
        }.padding(.bottom, 24).foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory.ignoresSafeArea())
            .task { if let selection { location.select(latitude: selection.latitude, longitude: selection.longitude) } }
            .onDisappear { location.stop() }
    }
}

struct PhotoLocationBadge: View {
    let name: String
    var edit: (() -> Void)? = nil
    var body: some View {
        HStack(spacing: 8) {
            LocationOutlineMark().stroke(style: FieldGuideTheme.navigationStroke)
                .frame(width: 24, height: 24).fixedSize().accessibilityHidden(true)
            Text(name).font(FieldGuideTheme.sans(14)).frame(maxWidth: .infinity, alignment: .leading)
            if let edit {
                Button(action: edit) {
                    EditOutlineMark().stroke(style: FieldGuideTheme.navigationStroke)
                        .frame(width: 22, height: 22).frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Fotolocatie bewerken")
            }
        }.padding(12).foregroundStyle(FieldGuideTheme.charcoal)
            .overlay { RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius)
                .stroke(FieldGuideTheme.charcoal.opacity(0.7), lineWidth: 0.6) }
    }
}
