import SwiftUI

struct EBirdConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    let query: DiscoverQuery?
    var didChange: () -> Void
    @State private var apiKey = ""
    @AppStorage("discoverRadiusKilometers") private var radius = DiscoverQuery.nearbyRadiusKilometers
    @AppStorage("discoverLookbackDays") private var days = DiscoverQuery.defaultLookbackDays
    @State private var hasStoredKey = false
    @State private var isChecking = false
    @State private var message: String?
    private let keys = EBirdKeychainStore()

    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Lokale vogelmeldingen") { dismiss() }
            Form {
                Section {
                    Text("Observation.org levert openbare vogelmeldingen. Verbind eBird om ook die bron toe te voegen.")
                    Link("Gratis eBird-sleutel aanvragen", destination: URL(string: "https://ebird.org/api/keygen")!)
                }
                Section("Zoekstraal") {
                    Text("Binnen \(Int(DiscoverQuery.validRadius(radius))) km")
                    Slider(value: Binding(get: { DiscoverQuery.validRadius(radius) }, set: { radius = DiscoverQuery.validRadius($0) }), in: 1...50, step: 1)
                        .accessibilityLabel("Zoekstraal in kilometer")
                    Text("Standaard 5 km. eBird zoekt tot 50 km, Observation.org vult aan tot 10 km. De ontdekpagina wordt automatisch bijgewerkt.").font(.footnote)
                }
                Section("Periode") {
                    Stepper(value: Binding(get: { DiscoverQuery.validLookbackDays(days) },
                                           set: { days = DiscoverQuery.validLookbackDays($0) }), in: 1...14) {
                        let value = DiscoverQuery.validLookbackDays(days)
                        Text("Afgelopen \(value) \(value == 1 ? "dag" : "dagen")")
                    }
                    Text("Standaard 3 dagen. Instelbaar van 1 tot 14 dagen voor beide bronnen.").font(.footnote)
                }
                Section("Persoonlijke API-sleutel") {
                    if hasStoredKey { Label("eBird is verbonden", systemImage: "checkmark.circle") }
                    SecureField(hasStoredKey ? "Nieuwe sleutel invoeren" : "Plak je eBird-sleutel", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isChecking)
                        .privacySensitive()
                    Text("Je sleutel wordt alleen op dit toestel in de sleutelhanger bewaard.")
                        .font(.footnote)
                    Button { message = nil; isChecking = true } label: {
                        if isChecking { ProgressView("Verbinding controleren…") }
                        else { Text("Verbind en haal vogels op") }
                    }
                    .disabled(isChecking || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let message { Text(message).foregroundStyle(.red).accessibilityAddTraits(.updatesFrequently) }
                }
                Section {
                    Text("De lijst combineert eBird en Observation.org voor de gekozen periode, met de recentste melding per soort bovenaan. Tijden zijn lokale waarnemingstijden; meldingen zonder uur worden binnen hun datum gesorteerd.")
                        .font(.footnote)
                }
                if hasStoredKey {
                    Section {
                        Button("Verbinding verwijderen", role: .destructive) {
                            do {
                                try keys.remove()
                                apiKey = ""
                                didChange()
                                dismiss()
                            } catch { message = error.localizedDescription }
                        }.disabled(isChecking)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(FieldGuideTheme.ivory)
            .foregroundStyle(FieldGuideTheme.charcoal)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                do { hasStoredKey = try keys.read() != nil }
                catch { message = error.localizedDescription }
            }
            .task(id: isChecking) {
                guard isChecking else { return }
                defer { isChecking = false }
                do {
                    // If GPS is not available yet, only verify access with a neutral
                    // coordinate; these results never become the user's nearby list.
                    let probe = query ?? DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: DiscoverQuery.validRadius(radius), daysBack: days)
                    _ = try await EBirdDiscoverRepository().reports(for: probe, apiKey: apiKey)
                    try Task.checkCancellation()
                    try keys.save(apiKey)
                    apiKey = ""
                    didChange()
                    dismiss()
                } catch is CancellationError {
                    // Closing the sheet never saves an unverified draft key.
                } catch {
                    if !Task.isCancelled { message = error.localizedDescription }
                }
            }
        }.foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory)
    }
}
