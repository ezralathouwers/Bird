import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DataBackupsView: View {
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var backups: BackupController
    @Environment(\.dismiss) private var dismiss
    @State private var chooseFolder = false
    @State private var chooseFile = false
    @State private var preview: BackupPreview?
    @State private var error: String?
    @State private var completed = false
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Gegevens en back-ups") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Bewaar je geschiedenis")
                        .font(FieldGuideTheme.sans(24, relativeTo: .title2))
                    Text("Je back-up bevat alle waarnemingen, sessies en doelstellingen. Kies een map in iCloud Drive om ze ook buiten deze iPhone te bewaren.")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Back-upmap").font(FieldGuideTheme.sans(17, relativeTo: .headline))
                        Text(backups.folderName ?? "Nog geen map gekozen").foregroundStyle(FieldGuideTheme.taupe)
                        action(backups.hasFolder ? "Andere map kiezen" : "Back-upmap kiezen", symbol: "folder") { chooseFolder = true }
                        Text("Kies een map buiten Birder. ‘Op mijn iPhone’ beschermt niet bij verlies of defect van je toestel.")
                            .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                    }.backupCard()
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Automatische back-ups", isOn: Binding(
                            get: { backups.automatic },
                            set: { backups.setAutomatic($0, store: store) }))
                            .disabled(!backups.hasFolder || backups.isBusy || store.loadError != nil)
                        Text("Na wijzigingen, zolang de app actief is. Elke back-up krijgt een eigen bestand; oudere versies blijven bewaard.")
                            .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                        Divider()
                        Text("Laatste geslaagde back-up").font(FieldGuideTheme.sans(17, relativeTo: .headline))
                        if let date = backups.lastSuccess {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                        } else { Text("Nog geen back-up gemaakt") }
                        Text("Birder controleert of het bestand goed geschreven is. iOS verzorgt de upload naar iCloud. Controleer in Bestanden of die klaar is voordat je de app verwijdert.")
                            .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                        action("Maak nu een back-up", symbol: "arrow.up.doc") { Task { await backups.save(store: store) } }
                            .disabled(!backups.hasFolder || store.loadError != nil)
                    }.backupCard()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Herstellen").font(FieldGuideTheme.sans(17, relativeTo: .headline))
                        Text("Kies een eerdere back-up. Je bekijkt eerst de inhoud voordat je huidige geschiedenis wordt vervangen.")
                            .font(FieldGuideTheme.sans(14))
                        action("Herstel vanuit back-up", symbol: "arrow.down.doc") { chooseFile = true }
                    }.backupCard()
                    if let loadError = store.loadError { Text(loadError) }
                    if backups.isBusy { ProgressView("Back-up verwerken…") }
                    if let message = backups.message { Text(message).foregroundStyle(FieldGuideTheme.charcoal) }
                    if let error { Text(error).foregroundStyle(FieldGuideTheme.charcoal) }
                    if completed { Text("Je geschiedenis is hersteld.") }
                    Text("Back-upbestanden bevatten je locaties en notities. Bewaar ze in een eigen, vertrouwde map.")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                }.padding(20).padding(.bottom, 40)
            }
        }.font(FieldGuideTheme.sans(15)).foregroundStyle(FieldGuideTheme.charcoal)
            .background(FieldGuideTheme.ivory.ignoresSafeArea())
            .sheet(isPresented: $chooseFolder) {
                BackupFolderPicker { url in
                    chooseFolder = false
                    if let url { Task { await backups.configure(folder: url, store: store) } }
                }
            }
            .fileImporter(isPresented: $chooseFile, allowedContentTypes: [.json]) { result in
                do {
                    let file = try result.get()
                    error = nil; completed = false
                    Task {
                        do { preview = try await backups.preview(file: file, store: store) }
                        catch { self.error = error.localizedDescription }
                    }
                } catch { self.error = error.localizedDescription }
            }
            .sheet(item: $preview) { item in
                BackupRestorePreview(preview: item) {
                    do {
                        try await backups.restore(item, store: store)
                        preview = nil; completed = true; error = nil
                    } catch { self.error = error.localizedDescription; preview = nil }
                }
            }
    }
    private func action(_ title: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 12)
        }.buttonStyle(.plain)
            .background(FieldGuideTheme.beige.opacity(0.6), in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
            .disabled(backups.isBusy)
    }
}

private extension View {
    func backupCard() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(FieldGuideTheme.beige.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct BackupRestorePreview: View {
    let preview: BackupPreview
    let restore: () async -> Void
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var backups: BackupController
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    private var needsFolder: Bool {
        !backups.hasFolder && (!store.observations.isEmpty || !store.sessions.isEmpty || !store.goals.isEmpty)
    }
    var body: some View {
        VStack(spacing: 0) {
            CenteredPageHeader(title: "Back-up bekijken") { dismiss() }.disabled(backups.isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let date = preview.createdAt { Text(date.formatted(date: .abbreviated, time: .shortened)) }
                    Text("\(preview.archive.observations.count) \(preview.archive.observations.count == 1 ? "waarneming" : "waarnemingen")")
                    Text("\(preview.archive.sessions.count) \(preview.archive.sessions.count == 1 ? "sessie" : "sessies")")
                    Text("\(preview.archive.goals?.count ?? 0) \(preview.archive.goals?.count == 1 ? "doelstelling" : "doelstellingen")")
                    Text("Herstellen vervangt alle huidige gegevens door deze back-up. Gegevens worden niet samengevoegd.")
                    Text("Eerst wordt een veiligheidskopie van de huidige gegevens gemaakt. Je oorspronkelijke lokale bestand blijft ook als herstelkopie bewaard.")
                        .font(FieldGuideTheme.sans(14))
                    if needsFolder { Text("Kies op het vorige scherm eerst een back-upmap voor je huidige gegevens.") }
                    if store.activeSession != nil { Text(BackupError.activeSession.localizedDescription) }
                    if backups.isBusy { ProgressView("Gegevens veiligstellen en herstellen…") }
                    Button("Herstel deze back-up") { confirm = true }
                        .frame(maxWidth: .infinity, minHeight: 52).foregroundStyle(FieldGuideTheme.ivory)
                        .background(FieldGuideTheme.charcoal, in: RoundedRectangle(cornerRadius: FieldGuideTheme.controlCornerRadius))
                        .disabled(needsFolder || store.activeSession != nil || backups.isBusy)
                }.padding(20)
            }
        }.foregroundStyle(FieldGuideTheme.charcoal).background(FieldGuideTheme.ivory.ignoresSafeArea())
            .interactiveDismissDisabled(backups.isBusy)
            .confirmationDialog("Huidige geschiedenis vervangen?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Vervang en herstel", role: .destructive) { Task { await restore() } }
                Button("Annuleren", role: .cancel) {}
            } message: { Text("Alle huidige waarnemingen, sessies en doelstellingen worden vervangen door de getoonde back-up.") }
    }
}

private struct BackupFolderPicker: UIViewControllerRepresentable {
    let completion: (URL?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator; picker.allowsMultipleSelection = false
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    @MainActor final class Coordinator: NSObject, @preconcurrency UIDocumentPickerDelegate {
        let completion: (URL?) -> Void
        init(completion: @escaping (URL?) -> Void) { self.completion = completion }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completion(urls.first) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completion(nil) }
    }
}
