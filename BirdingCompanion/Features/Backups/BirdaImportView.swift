import SwiftUI
import UniformTypeIdentifiers

struct BirdaImportView: View {
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var backups: BackupController
    @Environment(\.dismiss) private var dismiss
    @State private var choosing = false
    @State private var loading = false
    @State private var batch: BirdaImportBatch?
    @State private var plan: BirdaImportPlan?
    @State private var expectedRevision: UUID?
    @State private var error: String?
    @State private var completed: String?

    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Importeren uit Birda") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Kies je CSV-export uit Birda. De import wordt lokaal op je iPhone verwerkt.")
                    Button("Kies Birda-export (.csv)") { choosing = true }
                        .buttonStyle(.plain).modifier(ImportButtonStyle(dark: false)).disabled(loading)
                    if loading { ProgressView("Export controleren…") }
                    if let batch, let plan {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(batch.observations.count) waarnemingen · \(batch.speciesCount) soorten")
                                .font(FieldGuideTheme.sans(19, relativeTo: .headline))
                            Text("\(batch.sessions.count) sessies · \(batch.standaloneCount) losse waarnemingen")
                            Text("Nieuw: \(plan.addedObservations) waarnemingen en \(plan.addedSessions) sessies.")
                            if plan.skipped > 0 { Text("\(plan.skipped) eerder geïmporteerde waarnemingen worden overgeslagen, met behoud van je wijzigingen.") }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(FieldGuideTheme.beige.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                        Text("Aantal altijd 1. Het start- en einduur van elke sessie komen van de eerste en laatste waarneming. Groepen met één waarneming blijven losse waarnemingen.")
                        Text("De exacte tijdstippen en coördinaten blijven behouden. De export bevat geen landen of tijdzones. Zonder vastgestelde tijdzone tonen we geïmporteerde tijden expliciet in UTC. Locatienamen ontbreken bij losse waarnemingen; daar tonen we de coördinaten.")
                            .font(FieldGuideTheme.sans(14))
                        Text("Je huidige gegevens blijven behouden. Birder maakt vóór het toevoegen een lokale herstelkopie. Maak na de import ook een back-up in iCloud Drive.")
                            .font(FieldGuideTheme.sans(14))
                        if store.activeSession != nil { Text("Rond eerst je livesessie af.") }
                        Button("Importeer geschiedenis") { save() }
                            .buttonStyle(.plain).modifier(ImportButtonStyle(dark: true))
                            .disabled(loading || backups.isBusy || store.activeSession != nil || store.loadError != nil || completed != nil)
                    }
                    if let error { Text(error).accessibilityAddTraits(.updatesFrequently) }
                    if let completed { Text(completed).accessibilityAddTraits(.updatesFrequently) }
                }.padding(20).padding(.bottom, 50)
            }
        }.font(FieldGuideTheme.sans(16)).foregroundStyle(FieldGuideTheme.charcoal)
            .background(FieldGuideTheme.ivory.ignoresSafeArea())
            .fileImporter(isPresented: $choosing, allowedContentTypes: [.commaSeparatedText, .plainText, .data]) { result in
                switch result {
                case .success(let file): Task { await load(file) }
                case .failure(let failure): error = failure.localizedDescription
                }
            }
    }

    private func load(_ file: URL) async {
        loading = true; error = nil; completed = nil; batch = nil; plan = nil
        defer { loading = false }
        let revision = store.revision
        let catalog = SpeciesGuideCatalog.species
        do {
            if let message = SpeciesGuideCatalog.loadError { throw BirdaImportError(message: message) }
            let imported = try await Task.detached(priority: .userInitiated) {
                let accessed = file.startAccessingSecurityScopedResource()
                defer { if accessed { file.stopAccessingSecurityScopedResource() } }
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 16 * 1024 * 1024 else { throw BirdaImportError(message: "De CSV is groter dan 16 MB.") }
                return try BirdaImport.decode(Data(contentsOf: file), catalog: catalog)
            }.value
            guard store.revision == revision else { throw BirdaImportError(message: "Je geschiedenis is gewijzigd. Kies het bestand opnieuw.") }
            let prepared = try BirdaImport.plan(imported, observations: store.observations, sessions: store.sessions)
            batch = imported; plan = prepared; expectedRevision = revision
        } catch { self.error = error.localizedDescription }
    }
    private func save() {
        guard let batch, let expectedRevision else { return }
        do {
            let result = try store.importBirda(batch, expectedRevision: expectedRevision)
            completed = "Import voltooid: \(result.addedObservations) waarnemingen en \(result.addedSessions) sessies toegevoegd."
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

private struct ImportButtonStyle: ViewModifier {
    let dark: Bool
    func body(content: Content) -> some View {
        content.frame(maxWidth: .infinity, minHeight: 52).padding(.horizontal, 12)
            .foregroundStyle(dark ? FieldGuideTheme.ivory : FieldGuideTheme.charcoal)
            .background(dark ? FieldGuideTheme.charcoal : FieldGuideTheme.beige,
                in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
    }
}
