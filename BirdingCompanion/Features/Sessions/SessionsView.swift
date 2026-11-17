import SwiftUI
import UniformTypeIdentifiers

struct SessionsView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var creatingLive = false
    @State private var showForm = false
    @State private var selected: BirdSession?
    @State private var exporting = false
    @State private var exportDocument = ObservationExport(data: Data())
    @State private var error: String?
    @Binding var showLive: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    Text("Sessies").font(FieldGuideTheme.sans(34, relativeTo: .largeTitle))
                        .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                    RoundAction(symbol: "clock", label: "Voltooide sessie toevoegen") { creatingLive = false; showForm = true }
                    RoundAction(symbol: "play", label: "Nieuwe livesessie starten") { creatingLive = true; showForm = true }
                        .disabled(store.activeSession != nil || store.loadError != nil)
                }
                if let message = store.loadError { Text(message).foregroundStyle(.red) }
                if let active = store.activeSession {
                    Button { showLive = true } label: {
                        Label("\(active.locationName) · livesessie", systemImage: "play")
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    }
                    .padding(12).background(FieldGuideTheme.khaki.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                }
                if store.completedSessions.isEmpty, store.loadError == nil {
                    Text("Nog geen afgeronde sessies. Start een livesessie of voeg een eerdere sessie toe.")
                }
                ForEach(store.completedSessions) { session in
                    Button { selected = session } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.locationName).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                            Text(SessionPresentation.period(session)).font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                            Text("\(store.observations(in: session).count) waarnemingen")
                                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider().overlay(FieldGuideTheme.beige)
                }
                Button("Exporteer sessies en waarnemingen (JSON)") {
                    do { exportDocument = ObservationExport(data: try store.exportArchiveData()); exporting = true }
                    catch { self.error = error.localizedDescription }
                }.frame(minHeight: 44).disabled(store.loadError != nil)
                if let error { Text(error).foregroundStyle(.red) }
            }.padding(20).padding(.bottom, 24)
        }
        .background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showForm) {
            SessionForm(live: creatingLive) { if creatingLive { showLive = true } }
        }
        .sheet(item: $selected) { session in SessionDetailView(session: session) }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
            defaultFilename: "birding-sessies-en-waarnemingen") { result in
                if case .failure(let failure) = result { error = failure.localizedDescription }
            }
    }
}

private enum SessionPresentation {
    static func period(_ session: BirdSession) -> String {
        let start = session.startedAt.formatted(date: .abbreviated, time: .shortened)
        guard let end = session.endedAt else { return start }
        return "\(start) – \(end.formatted(date: .abbreviated, time: .shortened))"
    }
}

struct SessionForm: View {
    let live: Bool
    var onSaved: () -> Void
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = ObservationLocationModel()
    @State private var start = Date()
    @State private var end = Date()
    @State private var selected = Set<String>()
    @State private var search = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !live {
                        DatePicker("Begin", selection: $start, in: ...Date())
                        DatePicker("Einde", selection: $end, in: start...max(start, Date()))
                    }
                    Text("Locatie").font(FieldGuideTheme.sans(20, relativeTo: .title3))
                    ObservationLocationPicker(location: location).frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    TextField("Naam van natuurgebied of plaats", text: Binding(
                        get: { location.locationName }, set: { location.editName($0) }))
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Sessielocatie en naam")
                    if location.isLocating { ProgressView("Huidige locatie ophalen…") }
                    if location.isNaming { ProgressView("Plaatsnaam ophalen…") }
                    if let message = location.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                    Button { location.useCurrentLocation() } label: {
                        Label("Gebruik huidige locatie", systemImage: "location").frame(minHeight: 44)
                    }.disabled(location.isLocating)
                    if !live {
                        Text("Vogels selecteren").font(FieldGuideTheme.sans(20, relativeTo: .title3))
                        SessionSpeciesSearch(search: $search, selected: selected) { bird in
                            if selected.contains(bird.id) { selected.remove(bird.id) } else { selected.insert(bird.id) }
                        }
                        Text("\(selected.count) soorten geselecteerd")
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }
            .background(FieldGuideTheme.ivory)
            .safeAreaInset(edge: .bottom) {
                Button(live ? "Livesessie starten" : "Sessie opslaan", action: save)
                    .buttonStyle(SessionPrimaryButton())
                    .disabled(!location.canSave || store.loadError != nil || (!live && (selected.isEmpty || end < start)))
                    .padding(20).background(FieldGuideTheme.ivory)
            }
            .navigationTitle(live ? "Sessie starten" : "Sessie toevoegen").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Terug zonder opslaan")
                }
            }
            .task { location.useCurrentLocation() }.onDisappear { location.stop() }
            .onChange(of: start) { _, value in if end < value { end = value } }
        }
    }

    private func save() {
        guard location.canSave, let latitude = location.latitude, let longitude = location.longitude else { return }
        let now = Date()
        let session = BirdSession(locationName: location.locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: latitude, longitude: longitude, countryCode: location.countryCode,
            startedAt: live ? now : start, endedAt: live ? nil : end, isLive: live)
        do {
            if live { try store.startSession(session) }
            else { try store.addCompletedSession(session, species: DiscoverFixtures.catalog.filter { selected.contains($0.id) }) }
            dismiss(); onSaved()
        } catch { self.error = error.localizedDescription }
    }
}

struct SessionSpeciesSearch: View {
    @Binding var search: String
    var selected: Set<String> = []
    var disabled = false
    var choose: (Species) -> Void
    private var birds: [Species] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return DiscoverFixtures.catalog.filter {
            term.isEmpty || [$0.dutchName, $0.englishName, $0.scientificName].contains {
                $0.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }.sorted { $0.dutchName.localizedStandardCompare($1.dutchName) == .orderedAscending }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Zoek een vogel", text: $search).textFieldStyle(.roundedBorder)
                .autocorrectionDisabled().accessibilityLabel("Zoek op Nederlandse, Engelse of wetenschappelijke naam")
            if birds.isEmpty { Text("Geen soorten gevonden.") }
            ForEach(birds) { bird in
                Button { choose(bird) } label: {
                    HStack(spacing: 12) {
                        PrimaryBirdArtwork(species: bird).frame(width: 56, height: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bird.dutchName).font(.custom("Fraunces-9ptBlack", size: 16, relativeTo: .body).weight(.regular))
                            Text(bird.englishDisplayName).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected.contains(bird.id) ? "checkmark.circle" : "plus")
                            .font(.system(size: 20, weight: .light))
                    }.frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(disabled)
                    .accessibilityLabel("\(bird.dutchName), \(selected.contains(bird.id) ? "geselecteerd" : "toevoegen")")
            }
        }
    }
}

struct LiveSessionView: View {
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var logger: SessionLiveLogger
    @Binding var isPresented: Bool
    @State private var search = ""
    @State private var confirmFinish = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button { isPresented = false } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }.accessibilityLabel("Terug, sessie blijft actief")
                    Spacer()
                    Text("Livesessie").font(FieldGuideTheme.sans())
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                if let session = store.activeSession {
                    Text(session.locationName).font(FieldGuideTheme.sans(28, relativeTo: .title))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.elapsed(from: session.startedAt, to: context.date))
                            .font(FieldGuideTheme.sans(44, relativeTo: .largeTitle)).monospacedDigit()
                            .accessibilityLabel("Verstreken tijd \(Self.elapsed(from: session.startedAt, to: context.date))")
                    }
                    SessionSpeciesSearch(search: $search, disabled: logger.isLogging) { bird in logger.log(bird, store: store) }
                    if logger.isLogging { ProgressView("Actuele locatie ophalen en vogel opslaan…") }
                    if let message = logger.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                    let logs = store.observations(in: session)
                    Text("\(logs.count) waarnemingen").font(FieldGuideTheme.sans(24, relativeTo: .title2))
                    SessionLogsList(logs: logs)
                    if let error { Text(error).foregroundStyle(.red) }
                    Button("Livesessie afronden") { confirmFinish = true }
                        .buttonStyle(SessionPrimaryButton()).disabled(logger.isLogging)
                } else { Text("Geen actieve livesessie.") }
            }.padding(20).padding(.bottom, 36)
        }
        .background(FieldGuideTheme.ivory)
        .confirmationDialog("Livesessie afronden?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Sessie afronden") {
                do { try store.finishSession(); isPresented = false }
                catch { self.error = error.localizedDescription }
            }
            Button("Verder loggen", role: .cancel) {}
        } message: { Text("Alle opgeslagen waarnemingen blijven bewaard.") }
    }

    private static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

private struct SessionLogsList: View {
    let logs: [Observation]
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(logs) { log in
                HStack(spacing: 12) {
                    if let bird = DiscoverFixtures.catalog.first(where: { $0.id == log.speciesID }) {
                        PrimaryBirdArtwork(species: bird).frame(width: 52, height: 52)
                        Text(bird.dutchName).font(.custom("Fraunces-9ptBlack", size: 16, relativeTo: .body).weight(.regular))
                    } else { Text("Onbekende soort (\(log.speciesID))") }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(log.observedAt, style: .time)
                        Text(log.locationName)
                    }.font(FieldGuideTheme.sans(12, relativeTo: .caption))
                }
                Divider()
            }
        }
    }
}

private struct SessionDetailView: View {
    let session: BirdSession
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(session.locationName).font(FieldGuideTheme.sans(28, relativeTo: .title))
                    Text(SessionPresentation.period(session))
                    let logs = store.observations(in: session)
                    Text("\(logs.count) waarnemingen")
                    SessionLogsList(logs: logs)
                }.padding(20)
            }.background(FieldGuideTheme.ivory)
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Sluiten") { dismiss() } } }
        }
    }
}

struct LiveSessionAddBirdView: View {
    let species: Species
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var logger: SessionLiveLogger
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                PrimaryBirdArtwork(species: species).frame(height: 220)
                Text(species.dutchName).font(FieldGuideTheme.speciesTitle)
                Text("Deze vogel wordt in je livesessie opgeslagen met het huidige tijdstip en je actuele locatie.")
                if logger.isLogging { ProgressView("Actuele locatie ophalen…") }
                if let message = logger.message { Text(message) }
                Button("Vogel loggen") { logger.log(species, store: store) { dismiss() } }
                    .buttonStyle(SessionPrimaryButton()).disabled(logger.isLogging || store.activeSession == nil)
                Spacer()
            }.padding(20).background(FieldGuideTheme.ivory)
                .navigationTitle("Waarneming toevoegen").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Terug")
                } }
        }
    }
}

private struct SessionPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(FieldGuideTheme.sans()).frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(FieldGuideTheme.ivory)
            .background(FieldGuideTheme.charcoal, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}
