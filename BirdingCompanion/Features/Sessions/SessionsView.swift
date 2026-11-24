import SwiftUI

struct SessionRoute: Hashable { let id: UUID }
enum SessionLogSort: String, CaseIterable {
    case latest = "Laatste eerst", alphabetical = "Alfabetisch"
}
enum SessionStats {
    static func liferIDs(in logs: [Observation]) -> Set<UUID> {
        var first: [String: Observation] = [:]
        for log in logs {
            if let previous = first[log.speciesID],
               previous.observedAt < log.observedAt || (previous.observedAt == log.observedAt && previous.id.uuidString < log.id.uuidString) { continue }
            first[log.speciesID] = log
        }
        return Set(first.values.map(\.id))
    }
    static func duration(_ session: BirdSession) -> String {
        let minutes = max(0, Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt)) / 60)
        return minutes >= 60 ? "\(minutes / 60)u\(String(format: "%02d", minutes % 60))" : "\(minutes)min"
    }
    static func period(_ session: BirdSession) -> String {
        let day = session.historyDate(session.startedAt, time: .omitted)
        let start = session.historyDate(session.startedAt, day: .omitted)
        let end = session.historyDate(session.endedAt ?? Date(), day: .omitted)
        return "\(day) - \(start) tot \(end)"
    }
    static func bird(_ id: String) -> Species {
        SpeciesGuideCatalog.species(id: id) ?? Species(id: id, taxonomyVersion: "unknown",
            dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
    }
    static func sorted(_ logs: [Observation], by sort: SessionLogSort) -> [Observation] {
        logs.sorted {
            if sort == .alphabetical {
                let comparison = bird($0.speciesID).dutchName.localizedStandardCompare(bird($1.speciesID).dutchName)
                if comparison != .orderedSame { return comparison == .orderedAscending }
            }
            return $0.observedAt == $1.observedAt ? $0.id.uuidString < $1.id.uuidString : $0.observedAt > $1.observedAt
        }
    }
}

private enum NewSessionMode: String, Identifiable {
    case live, completed
    var id: String { rawValue }
}

struct SessionsView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var newSession: NewSessionMode?
    @Binding var showLive: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                PageHeading(text: "Sessies").frame(maxWidth: .infinity, alignment: .leading)
                RoundAction(symbol: "clock", label: "Voltooide sessie toevoegen") { newSession = .completed }
                RoundAction(symbol: "play", label: "Nieuwe livesessie starten") { newSession = .live }
                .disabled(store.activeSession != nil || store.loadError != nil)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            .fixedSize(horizontal: false, vertical: true)
            CatalogResultsScroll(resetKey: "sessions") {
                LazyVStack(alignment: .leading, spacing: 24) {

                    if let message = store.loadError { Text(message).foregroundStyle(.red) }
                    if let active = store.activeSession {
                        Button { showLive = true } label: {
                            HStack {
                                Text("\(active.locationName) · livesessie"); Spacer()
                                FineControlIcon(symbol: "play", size: 18)
                            }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        }.buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 12)
                        .background(FieldGuideTheme.khaki.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if store.completedSessions.isEmpty, store.loadError == nil { Text("Nog geen afgeronde sessies.") }
                    let lifers = SessionStats.liferIDs(in: store.observations)
                    ForEach(store.completedSessions) { session in
                        NavigationLink(value: SessionRoute(id: session.id)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.locationName).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                                Text("\(session.historyDate(session.startedAt, time: .omitted)) · \(SessionStats.duration(session))")
                                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                let logs = store.observations(in: session)
                                let count = logs.filter { lifers.contains($0.id) }.count
                                Text("\(logs.count) \(logs.count == 1 ? "waarneming" : "waarnemingen")" + (count > 0 ? " · \(count) \(count == 1 ? "lifer" : "lifers")" : ""))
                                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding(.horizontal, 20).padding(.bottom, 94)
            }
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $newSession) { mode in
            SessionForm(live: mode == .live) { if mode == .live { showLive = true } }.id(mode)
        }
        .navigationDestination(for: SessionRoute.self) { route in SessionDetailView(sessionID: route.id) }
        .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
    }
}


struct SessionForm: View {
    let live: Bool
    var reviewing: BirdSession? = nil
    var onSaved: () -> Void
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location: ObservationLocationModel
    @State private var start = Date()
    @State private var end = Date()
    @State private var selected = Set<String>()
    @State private var error: String?
    @State private var reviewLogs: [Observation] = []
    @State private var originalLogs: [Observation] = []
    @State private var initialized = false
    @State private var showSearch = false
    @State private var confirmDelete = false
    @State private var confirmConvert = false
    init(live: Bool, reviewing: BirdSession? = nil, onSaved: @escaping () -> Void) {
        self.live = live; self.reviewing = reviewing; self.onSaved = onSaved
        let seed: Observation? = reviewing.map { session in
            var record = Observation(speciesID: "location-seed", taxonomyVersion: "location-only",
                observedAt: session.startedAt, locationName: session.locationName, count: 1, notes: "", status: .confirmed)
            record.latitude = session.latitude; record.longitude = session.longitude; record.countryCode = session.countryCode
            return record
        }
        _location = StateObject(wrappedValue: ObservationLocationModel(observation: seed))
    }
    private var title: String {
        live ? "Sessie starten" : reviewing == nil ? "Sessie toevoegen" : reviewing?.endedAt == nil ? "Sessie afronden" : "Sessie bewerken"
    }
    private var selectedIDs: Set<String> { reviewing == nil ? selected : Set(reviewLogs.map(\.speciesID)) }
    private var day: Binding<Date> {
        Binding(get: { start }, set: { date in
            var calendar = Calendar.current
            calendar.timeZone = reviewing?.historyTimeZone ?? .current
            let delta = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
            let revised = calendar.date(byAdding: .day, value: delta, to: start) ?? start
            shiftLogs(by: revised.timeIntervalSince(start))
            start = revised; end = calendar.date(byAdding: .day, value: delta, to: end) ?? end
        })
    }
    private var startTime: Binding<Date> {
        Binding(get: { start }, set: { value in shiftLogs(by: value.timeIntervalSince(start)); start = value })
    }
    private func shiftLogs(by interval: TimeInterval) {
        for index in reviewLogs.indices { reviewLogs[index].observedAt = reviewLogs[index].observedAt.addingTimeInterval(interval) }
    }
    @ViewBuilder private var dateFields: some View {
        DateTimeField(title: "Datum", selection: day, isDate: true, latestDate: Date())
        DateTimeField(title: "Startuur", selection: startTime, isDate: false)
        DateTimeField(title: "Einduur", selection: $end, isDate: false)
    }
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: title) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !live {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) { dateFields }
                            ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 6) { dateFields } }
                        }
                    }
                    ObservationLocationPicker(location: location).frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    BirdTextField("Naam van natuurgebied of plaats", text: Binding(get: { location.locationName }, set: { location.editName($0) }))
                        .font(FieldGuideTheme.sans(22, relativeTo: .title2)).modifier(RoundedSearchField())
                    if location.isLocating { ProgressView("Huidige locatie ophalen…") }
                    if let message = location.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                    if reviewing == nil {
                        Button { location.useCurrentLocation() } label: { Label("Gebruik huidige locatie", systemImage: "location").frame(minHeight: 44) }
                            .disabled(location.isLocating)
                    }
                    if !live {
                        Text("\(reviewing == nil ? selected.count : reviewLogs.count) \((reviewing == nil ? selected.count : reviewLogs.count) == 1 ? "waarneming" : "waarnemingen")")
                            .font(FieldGuideTheme.sans(24, relativeTo: .title2))
                        SessionSearchLauncher { showSearch = true }.padding(.bottom, -12)
                        if reviewing != nil {
                            SessionLogsList(logs: reviewLogs, showsTime: false, liferIDs: SessionStats.liferIDs(in: store.observations.filter { $0.sessionID != reviewing?.id } + reviewLogs), remove: { log in reviewLogs.removeAll { $0.id == log.id } })
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(selected.sorted(), id: \.self) { id in
                                    SessionBirdRow(bird: SessionStats.bird(id)) {
                                        RemoveSessionBirdButton { selected.remove(id) }
                                    }
                                    Divider()
                                }
                            }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button(live ? "Livesessie starten" : reviewing == nil ? "Sessie opslaan" : reviewing?.endedAt == nil ? "Sessie afronden" : "Wijzigingen opslaan", action: save)
                        .buttonStyle(SessionPrimaryButton())
                        .disabled(!location.canSave || store.loadError != nil || (live && store.activeSession != nil) || (!live && reviewing == nil && selected.isEmpty))
                    if let reviewing {
                        if reviewing.endedAt != nil {
                            Button("Omzetten in waarnemingen") { confirmConvert = true }
                                .frame(maxWidth: .infinity, minHeight: 44).disabled(store.loadError != nil)
                        }
                        Button("Sessie verwijderen", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity, minHeight: 44).disabled(store.loadError != nil)
                    }
                }.padding(20).background(FieldGuideTheme.ivory)
            }
        }.background(FieldGuideTheme.ivory.ignoresSafeArea())
            .environment(\.timeZone, reviewing?.historyTimeZone ?? .current)
            .confirmationDialog("Sessie verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Verwijder sessie en waarnemingen", role: .destructive) { removeSession(keepObservations: false) }
                Button("Annuleren", role: .cancel) {}
            } message: { Text("Deze sessie en alle bijbehorende waarnemingen worden verwijderd.") }
            .confirmationDialog("Omzetten in losse waarnemingen?", isPresented: $confirmConvert, titleVisibility: .visible) {
                Button("Omzetten in waarnemingen") { removeSession(keepObservations: true) }
                Button("Annuleren", role: .cancel) {}
            } message: { Text("De opgeslagen waarnemingen behouden hun tijdstip en locatie. De sessie wordt verwijderd.") }
            .task {
                guard !initialized else { return }; initialized = true
                if let reviewing {
                    start = reviewing.startedAt; end = reviewing.endedAt ?? Date()
                    reviewLogs = store.observations(in: reviewing); originalLogs = reviewLogs
                } else { location.useCurrentLocation() }
            }
            .onDisappear { if !showSearch { location.stop() } }
            .fullScreenCover(isPresented: $showSearch) {
                SessionSpeciesPicker(selected: selectedIDs, latitude: location.latitude, longitude: location.longitude, date: start) { bird in
                    if reviewing != nil {
                        guard !selectedIDs.contains(bird.id), let latitude = location.latitude, let longitude = location.longitude else { return }
                        var log = Observation(speciesID: bird.id, taxonomyVersion: bird.taxonomyVersion, observedAt: start,
                            locationName: location.locationName, count: 1, notes: "", status: .confirmed)
                        log.latitude = latitude; log.longitude = longitude; log.countryCode = location.countryCode
                        log.sessionID = reviewing?.id; log.source = "session-review"
                        log.timeZoneIdentifier = reviewing?.historyTimeZone.identifier
                        reviewLogs.append(log)
                    } else { selected.insert(bird.id) }
                }
            }
    }
    private func removeSession(keepObservations: Bool) {
        guard let reviewing else { return }
        do { try store.deleteSession(id: reviewing.id, keepObservations: keepObservations); dismiss(); onSaved() }
        catch { self.error = error.localizedDescription }
    }
    private func save() {
        guard location.canSave, let latitude = location.latitude, let longitude = location.longitude else { return }
        var calendar = Calendar.current
        calendar.timeZone = reviewing?.historyTimeZone ?? .current
        let resolvedEnd = end < start ? calendar.date(byAdding: .day, value: 1, to: end) ?? end : end
        var session = BirdSession(locationName: location.locationName.trimmingCharacters(in: .whitespacesAndNewlines), latitude: latitude,
            longitude: longitude, countryCode: location.countryCode, startedAt: live ? Date() : start,
            endedAt: live ? nil : resolvedEnd, isLive: reviewing?.isLive ?? live)
        do {
            if let reviewing {
                session.id = reviewing.id
                session.importMetadata = reviewing.importMetadata
                session.timeZoneIdentifier = reviewing.timeZoneIdentifier
                var logs = reviewLogs
                if !reviewing.isLive && reviewing.importMetadata?["source"] != "birda-csv" {
                    for index in logs.indices {
                        logs[index].observedAt = start; logs[index].latitude = latitude; logs[index].longitude = longitude
                        logs[index].locationName = session.locationName; logs[index].countryCode = session.countryCode
                    }
                }
                if reviewing.endedAt == nil { try store.completeSession(session, logs: logs, expectedLogs: originalLogs) }
                else { try store.updateCompletedSession(session, logs: logs, expectedLogs: originalLogs) }
            } else if live { try store.startSession(session) }
            else { try store.addCompletedSession(session, species: SpeciesGuideCatalog.species.filter { selected.contains($0.id) }) }
            dismiss(); onSaved()
        } catch { self.error = error.localizedDescription }
    }
}

private struct SessionSearchLauncher: View {
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack { Image(systemName: "magnifyingglass"); Text("Zoek een vogel"); Spacer() }
                .foregroundStyle(FieldGuideTheme.taupe).modifier(RoundedSearchField())
        }.buttonStyle(.plain).accessibilityLabel("Waarnemingen toevoegen")
    }
}

struct SessionSpeciesPicker: View {
    var selected: Set<String> = []
    var disabled = false
    var latitude: Double? = nil
    var longitude: Double? = nil
    var date: Date = Date()
    let choose: (Species) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @StateObject private var nearby = DiscoverViewModel()
    @FocusState private var focused: Bool
    private var birds: [Species] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !nearby.rows.isEmpty { return nearby.rows.map(\.species) }
        return SpeciesCatalogSearch.results(for: search, in: SpeciesGuideCatalog.species)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SpeciesBackButton { dismiss() }.padding(.top, 4)
            Text("Waarnemingen toevoegen").font(FieldGuideTheme.sans(24, relativeTo: .title2))
            BirdTextField("Zoek een vogel", text: $search).modifier(RoundedSearchField()).autocorrectionDisabled().focused($focused)
            CatalogResultsScroll(resetKey: search) {
                LazyVStack(spacing: 0) {
                    if nearby.isLoading && search.isEmpty { ProgressView("Vogels ophalen…") }
                    ForEach(birds) { bird in
                        Button { choose(bird); dismiss() } label: {
                            SessionBirdRow(bird: bird) {
                                FineControlIcon(symbol: selected.contains(bird.id) ? "checkmark.circle" : "plus")
                                    .font(.system(size: 20, weight: .light))
                            }
                        }.buttonStyle(.plain).disabled(disabled || selected.contains(bird.id))
                            .opacity(selected.contains(bird.id) ? 0.45 : 1)
                        Divider()
                    }
                    if birds.isEmpty && !nearby.isLoading { Text("Geen soorten gevonden.") }
                }.padding(.bottom, 24)
            }
        }.padding(.horizontal, 20).background(FieldGuideTheme.ivory.ignoresSafeArea())
            .task {
                focused = true
                if let latitude, let longitude {
                    await nearby.load(query: DiscoverQuery(latitude: latitude, longitude: longitude, now: date, radiusKilometers: DiscoverQuery.nearbyRadiusKilometers))
                }
            }
    }
}

struct LiveSessionView: View {
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var logger: SessionLiveLogger
    @Binding var isPresented: Bool
    var onFinished: () -> Void = {}
    var openAudio: () -> Void = {}
    @State private var showSearch = false
    @State private var reviewSession: BirdSession?
    @State private var finishedReview = false
    @State private var error: String?
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Livesessie") { isPresented = false }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let session = store.activeSession {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(Self.elapsed(from: session.startedAt, to: context.date))
                                .font(FieldGuideTheme.sans(44, relativeTo: .largeTitle)).monospacedDigit()
                        }.frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(FieldGuideTheme.beige.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                        SessionSearchLauncher { showSearch = true }
                        Button(action: openAudio) {
                            Label("Audio ID", systemImage: "waveform").frame(maxWidth: .infinity, minHeight: 48)
                        }.background(FieldGuideTheme.beige.opacity(0.3), in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
                        if logger.isLogging { ProgressView("Actuele locatie ophalen…") }
                        if let message = logger.message { Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote)) }
                        if let error { Text(error).foregroundStyle(.red) }
                        let logs = store.observations(in: session)
                        Text("\(logs.count) \(logs.count == 1 ? "waarneming" : "waarnemingen")").font(FieldGuideTheme.sans(24, relativeTo: .title2))
                        SessionLogsList(logs: logs, remove: { log in
                            do { try store.removeLiveObservation(id: log.id, sessionID: session.id) }
                            catch { self.error = error.localizedDescription }
                        })
                        Button("Livesessie afronden") { reviewSession = session }.buttonStyle(SessionPrimaryButton()).disabled(logger.isLogging)
                    } else { Text("Geen actieve livesessie.") }
                }.padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 36)
            }
        }.background(FieldGuideTheme.ivory)
            .fullScreenCover(isPresented: $showSearch) {
                if let session = store.activeSession {
                    SessionSpeciesPicker(selected: Set(store.observations(in: session).map(\.speciesID)), disabled: logger.isLogging,
                        latitude: session.latitude, longitude: session.longitude) { logger.log($0, store: store) }
                }
            }
            .fullScreenCover(item: $reviewSession, onDismiss: {
                if finishedReview { isPresented = false; onFinished() }
            }) { session in
                SessionForm(live: false, reviewing: session) { finishedReview = true; reviewSession = nil }
            }
    }
    private static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }
}

private struct SessionBirdRow<Trailing: View>: View {
    let bird: Species
    let trailing: () -> Trailing
    init(bird: Species, @ViewBuilder trailing: @escaping () -> Trailing) { self.bird = bird; self.trailing = trailing }
    var body: some View {
        HStack(spacing: 12) {
            PrimaryBirdArtwork(species: bird).frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                SerifText(bird.dutchName, size: 16, relativeTo: .body)
                Text(bird.englishDisplayName).font(FieldGuideTheme.sans(11.2, relativeTo: .caption)).foregroundStyle(FieldGuideTheme.taupe)
            }.frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }.padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).contentShape(Rectangle())
    }
}
private struct RemoveSessionBirdButton: View {
    let remove: () -> Void
    var body: some View {
        Button(action: remove) { FineControlIcon(symbol: "minus.circle", size: 20).frame(width: 44, height: 44) }
            .buttonStyle(.plain).accessibilityLabel("Verwijder waarneming")
    }
}
private struct SessionLogsList: View {
    let logs: [Observation]
    var showsTime = true
    var liferIDs: Set<UUID>? = nil
    var remove: ((Observation) -> Void)? = nil
    @EnvironmentObject private var store: ObservationStore
    var body: some View {
        let lifers = liferIDs ?? SessionStats.liferIDs(in: store.observations)
        LazyVStack(spacing: 0) {
            ForEach(logs) { log in
                SessionBirdRow(bird: SessionStats.bird(log.speciesID)) {
                    HStack(spacing: 4) {
                        if lifers.contains(log.id) { LiferStar().fill(FieldGuideTheme.khaki).frame(width: 18, height: 18).padding(.trailing, showsTime ? 8 : 0).foregroundStyle(FieldGuideTheme.khaki).accessibilityLabel("Lifer") }
                        if showsTime { Text(log.historyDate(day: .omitted)).font(FieldGuideTheme.sans(12, relativeTo: .caption)) }
                        if let remove { RemoveSessionBirdButton { remove(log) } }
                    }
                }
                Divider()
            }
        }
    }
}
private struct SessionDetailView: View {
    let sessionID: UUID
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var showMap = false
    @State private var sort: SessionLogSort = .latest
    private var current: BirdSession? { store.sessions.first { $0.id == sessionID } }
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Sessie").font(FieldGuideTheme.sans(17, relativeTo: .headline)).padding(.horizontal, 100)
                HStack {
                    SpeciesBackButton { dismiss() }
                    Spacer()
                    RoundAction(symbol: "map", label: "Bekijk sessie op de kaart") { showMap = true }
                    RoundEditAction(label: "Sessie bewerken") { editing = true }
                }
            }.frame(minHeight: 44).padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 4)
            ScrollView {
                if let session = current {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.locationName).font(FieldGuideTheme.sans(28, relativeTo: .title))
                        Text(SessionStats.period(session)).font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                        let logs = store.observations(in: session)
                        HStack(alignment: .top) {
                            ObservationTotal(value: logs.count, label: "waarnemingen")
                            Spacer()
                            Menu {
                                Picker("Sortering", selection: $sort) {
                                    ForEach(SessionLogSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                                }
                            } label: {
                                FineControlIcon(symbol: "arrow.up.arrow.down", size: 20)
                                    .frame(width: 44, height: 44)
                                    .background(FieldGuideTheme.searchControlBackground, in: Circle())
                            }.accessibilityLabel("Sortering").accessibilityValue(sort.rawValue)
                        }.padding(.top, 16).padding(.bottom, 12)
                        SessionLogsList(logs: SessionStats.sorted(logs, by: sort))
                    }.padding(20).padding(.bottom, 59)
                }
            }
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showMap) {
                if let session = current { FirstObservationsMapView(observations: store.observations(in: session), mapTitle: "Sessiekaart") }
            }
            .fullScreenCover(isPresented: $editing) {
                if let session = current { SessionForm(live: false, reviewing: session) {} }
            }
            .onChange(of: current == nil) { _, missing in if missing { dismiss() } }
    }
}

struct LiveSessionAddBirdView: View {
    let species: Species
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var logger: SessionLiveLogger
    @Environment(\.dismiss) private var dismiss
    private var duplicate: Bool { store.activeSession.map { store.observations(in: $0).contains { $0.speciesID == species.id } } ?? false }
    var body: some View {
        VStack(spacing: 20) {
            CenteredPageHeader(title: "Waarneming toevoegen") { dismiss() }
            PrimaryBirdArtwork(species: species).frame(height: 180)
            SerifText(species.dutchName, size: 30, relativeTo: .title)
            Text(species.englishDisplayName).font(FieldGuideTheme.sans(14))
            if logger.isLogging { ProgressView("Actuele locatie ophalen…") }
            if let message = logger.message { Text(message) }
            Button(duplicate ? "Reeds toegevoegd" : "Vogel loggen") { logger.log(species, store: store) { dismiss() } }
                .buttonStyle(SessionPrimaryButton()).disabled(logger.isLogging || store.activeSession == nil || duplicate).padding(.horizontal, 20)
            Spacer()
        }.background(FieldGuideTheme.ivory)
    }
}
private struct SessionPrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(FieldGuideTheme.sans()).frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(FieldGuideTheme.ivory).background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}
