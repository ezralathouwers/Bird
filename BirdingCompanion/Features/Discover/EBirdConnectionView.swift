import SwiftUI

struct EBirdConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    let query: DiscoverQuery?
    var didChange: () -> Void
    @State private var apiKey = ""
    @State private var hasStoredKey = false
    @State private var isChecking = false
    @State private var message: String?
    private let keys = EBirdKeychainStore()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Verbind eBird om recent gemelde vogelsoorten binnen 10 km te bekijken.")
                    Link("Gratis eBird-sleutel aanvragen", destination: URL(string: "https://ebird.org/api/keygen")!)
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
                    Text("De lijst toont soorten die de afgelopen 30 dagen zijn gemeld, alfabetisch op Nederlandse naam. eBird geeft hier per soort alleen de recentste melding door.")
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
            .navigationTitle("Lokale vogelmeldingen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Sluiten") { dismiss() } } }
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
                    let probe = query ?? DiscoverQuery(latitude: 0, longitude: 0, now: Date(), radiusKilometers: 10)
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
        }
    }
}
