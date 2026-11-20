import SwiftUI
import PhotosUI
@preconcurrency import AVFoundation

struct IdentificationView: View {
    var isVisible: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Identificeer").font(FieldGuideTheme.sans(34, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                NavigationLink {
                    PhotoIdentificationView()
                } label: { option("Foto-ID", detail: "Maak of kies een foto", symbol: "camera") }
                NavigationLink {
                    SoundIdentificationView(isVisible: isVisible)
                } label: { option("Geluid-ID", detail: "Luister naar vogels om je heen", symbol: "waveform") }
            }.padding(20)
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
    }
    private func option(_ name: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: symbol).font(.system(size: 36, weight: .ultraLight)).frame(width: 52)
            VStack(alignment: .leading, spacing: 8) {
                Text(name).font(FieldGuideTheme.sans(24, relativeTo: .title2))
                Text(detail).font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
        }.padding(24).frame(minHeight: 148)
            .foregroundStyle(FieldGuideTheme.charcoal)
            .background(FieldGuideTheme.beige.opacity(0.22), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct SoundIdentificationView: View {
    let isVisible: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = SoundIdentificationModel()
    @StateObject private var pins = SoundResultPins()
    @State private var selectedSpecies: Species?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                identificationHeader("Geluid-ID") { model.stop(); dismiss() }
                HStack {
                    Image(systemName: model.isRecording ? "mic.fill" : "mic")
                    Text(model.isRecording ? "Aan het luisteren" : "Opname gestopt").font(FieldGuideTheme.sans(20, relativeTo: .title3))
                    Spacer()
                    if model.isRecording, let startedAt = model.startedAt {
                        Text(startedAt, style: .timer).monospacedDigit()
                    } else { Text(Self.elapsed(model.duration)).monospacedDigit() }
                }
                CompactSonogram(columns: model.columns).frame(height: 120)
                HStack(spacing: 16) {
                    Button {
                        if model.isRecording { Task { await model.finishAndIdentify() } }
                        else { Task { await model.start() } }
                    } label: {
                        Label(model.isRecording ? "Stop opname" : "Opnemen", systemImage: model.isRecording ? "stop.fill" : "mic")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }.foregroundStyle(FieldGuideTheme.ivory).background(FieldGuideTheme.charcoal, in: Capsule())
                        .disabled(model.isStarting || model.isIdentifying)
                    if !model.isRecording, let url = model.recordingURL {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                            .accessibilityLabel("Exporteer deze opname")
                    }
                }
                if model.isStarting { ProgressView("Geluid-ID voorbereiden…") }
                if model.isIdentifying { ProgressView("Opname analyseren…") }
                Link("Fotoherkenning: BioCLIP 2 · MIT", destination: URL(string: "https://huggingface.co/imageomics/bioclip-2")!)
                    .font(FieldGuideTheme.sans(12, relativeTo: .caption))
                Text("Mogelijke vogels").font(FieldGuideTheme.sans(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                if let message = model.message { Text(message).font(FieldGuideTheme.sans(14, relativeTo: .subheadline)) }
                if let message = pins.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    SoundIdentificationResults(candidates: model.candidates, pins: pins,
                        activeIDs: model.activity.activeIDs(at: context.date, recording: model.isRecording)) { selectedSpecies = $0 }
                }
            }.padding(20).padding(.bottom, 24)
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .task { if isVisible { await model.start() } }
            .onDisappear { model.stop() }
            .onChange(of: isVisible) { _, visible in if !visible { model.stop() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background || (phase == .inactive && model.isRecording) { model.stop() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in model.stop() }
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

private struct PhotoIdentificationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PhotoIdentificationModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var importing = false
    @State private var error: String?
    @State private var cameraPhoto: Data?
    @State private var crop: PhotoCropSelection?
    @State private var recognitionTask: Task<Void, Never>?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                identificationHeader("Foto-ID") { dismiss() }
                HStack(spacing: 16) {
                    Button { Task { await openCamera() } } label: {
                        Label("Maak foto", systemImage: "camera").frame(maxWidth: .infinity, minHeight: 52)
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        Label("Kies foto", systemImage: "photo").frame(maxWidth: .infinity, minHeight: 52)
                    }
                }.buttonStyle(.bordered)
                if let data = model.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityLabel("Geselecteerde vogelfoto")
                } else {
                    RoundedRectangle(cornerRadius: 16).fill(FieldGuideTheme.beige.opacity(0.22)).frame(height: 240)
                        .overlay { Image(systemName: "photo").font(.system(size: 48, weight: .ultraLight)) }
                }
                Text("Analyse gebeurt op je iPhone. De eerste keer worden het model en de soortreferenties gedownload (ongeveer 297 MB). Niet alle soorten uit de gids worden ondersteund.")
                    .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                if model.photo != nil {
                    Text("Resultaten zijn gerangschikt op modelovereenkomst, niet op een betrouwbaarheidspercentage.")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                }
                if importing { ProgressView("Foto openen…") }
                if model.isLoading { ProgressView("Foto analyseren…") }
                if let error { Text(error).foregroundStyle(.red) }
                if let message = model.message { Text(message).font(FieldGuideTheme.sans(14, relativeTo: .subheadline)) }
                Text("Mogelijke vogels").font(FieldGuideTheme.sans(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
                if model.photo == nil { Text("Maak of kies een foto om herkenningssuggesties te bekijken.") }
                IdentificationResults(candidates: model.candidates)
            }.padding(20).padding(.bottom, 24)
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
                PhotoCropView(data: selection.data) { data in
                    crop = nil
                    guard let data else { return }
                    recognitionTask?.cancel()
                    recognitionTask = Task { await model.identify(data) }
                }
            }
            .onDisappear { recognitionTask?.cancel(); model.cancel() }
            .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
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
        ForEach(SoundResultOrdering.rows(candidates: candidates, pins: pins.species)) { row in
            HStack(spacing: 16) {
                PrimaryBirdArtwork(species: row.species).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(row.species.dutchName)
                            .font(.custom("Fraunces-9ptBlack", size: 18, relativeTo: .body).weight(.regular))
                        if row.isPinned {
                            Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(FieldGuideTheme.khaki)
                        }
                    }
                    Text(row.species.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
            }
            .frame(minHeight: 72).padding(.horizontal, 12).padding(.vertical, 4)
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
            .contextMenu {
                Button(row.isPinned ? "Losmaken" : "Vastzetten", systemImage: row.isPinned ? "star.slash" : "star") {
                    pins.toggle(row.species)
                }
                Button("Bekijk soort", systemImage: "bird") { open(row.species) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(row.species.dutchName), \(row.species.englishDisplayName)\(row.isPinned ? ", vastgezet" : "")\(activeIDs.contains(row.id) ? ", nu gehoord" : "")")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opent de soortpagina. Via Acties kun je deze vogel vastzetten of losmaken.")
            .accessibilityAction { open(row.species) }
            .accessibilityAction(named: Text(row.isPinned ? "Losmaken" : "Vastzetten")) { pins.toggle(row.species) }
            Divider()
        }
        if !candidates.isEmpty {
            Text("Herkenning is een suggestie. Controleer de soort voor je een waarneming toevoegt.")
                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
        }
    }
}

private struct IdentificationResults: View {
    let candidates: [IdentificationCandidate]
    var body: some View {
        ForEach(candidates) { candidate in
            NavigationLink(value: candidate.species) {
                HStack(spacing: 16) {
                    PrimaryBirdArtwork(species: candidate.species).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(candidate.species.dutchName).font(.custom("Fraunces-9ptBlack", size: 18, relativeTo: .body).weight(.regular))
                        Text(candidate.species.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
                }.frame(minHeight: 72).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Divider()
        }
        if !candidates.isEmpty {
            Text("Herkenning is een suggestie. Controleer de soort voor je een waarneming toevoegt.")
                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
        }
    }
}

@MainActor
private func identificationHeader(_ title: String, back: @escaping () -> Void) -> some View {
    HStack {
        Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 22, weight: .light)).frame(width: 44, height: 44) }
            .accessibilityLabel("Terug naar identificatie")
        Text(title).font(FieldGuideTheme.sans(24, relativeTo: .title2)).accessibilityAddTraits(.isHeader)
        Spacer()
    }
}
