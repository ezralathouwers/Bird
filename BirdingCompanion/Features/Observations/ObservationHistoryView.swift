import SwiftUI
import UniformTypeIdentifiers

struct ObservationHistoryView: View {
    let species: Species
    var embedded = false
    @EnvironmentObject private var store: ObservationStore
    @State private var editing: Observation?
    @State private var exporting = false
    @State private var exportDocument = ObservationExport(data: Data())
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let loadError = store.loadError { Text(loadError).foregroundStyle(.red) }
            let records = store.observations.filter { $0.speciesID == species.id }.sorted { $0.observedAt > $1.observedAt }
            if records.isEmpty && store.loadError == nil { Text("Nog geen waarnemingen. Voeg er een toe met + op de soortpagina.") }
            ForEach(records) { record in
                Button { editing = record } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.observedAt.formatted(date: .abbreviated, time: .shortened))
                        Text("\(record.count) · \(record.locationName.isEmpty ? "Geen locatie" : record.locationName)")
                        Text(record.status == .confirmed ? "Bevestigd" : "Onzeker").font(.caption)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.accessibilityHint("Bewerk deze waarneming")
            }
            Button("Exporteer alle waarnemingen (JSON)") {
                do { exportDocument = ObservationExport(data: try store.exportData()); exporting = true }
                catch { errorMessage = error.localizedDescription }
            }.frame(minHeight: 44).disabled(store.loadError != nil)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .padding(embedded ? 0 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $editing) { record in ObservationForm(species: species, observation: record) }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                      defaultFilename: "birding-waarnemingen") { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
    }
}

struct ObservationExport: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
