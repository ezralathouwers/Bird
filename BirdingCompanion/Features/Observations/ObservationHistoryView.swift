import SwiftUI
import UniformTypeIdentifiers

struct ObservationHistoryView: View {
    let species: Species
    var embedded = false
    var showsExport = true
    var prominentTotal = false
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var navigation: ObservationNavigation
    @State private var exporting = false
    @State private var exportDocument = ObservationExport(data: Data())
    @State private var errorMessage: String?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if let loadError = store.loadError { Text(loadError).foregroundStyle(.red) }
            let records = store.observations(for: species.id)
            if store.loadError == nil {
                if prominentTotal {
                    ObservationTotal(value: records.count, label: "waarnemingen")
                        .padding(.top, 12).padding(.bottom, 4)
                } else {
                    Text("\(records.count)")
                        .accessibilityLabel("\(records.count) \(records.count == 1 ? "waarneming" : "waarnemingen")")
                        .font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                        .foregroundStyle(FieldGuideTheme.charcoal)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            if records.isEmpty && store.loadError == nil { Text("Nog geen waarnemingen. Voeg er een toe met + op de soortpagina.") }
            ForEach(records) { record in
                Button { navigation.open(record, species: species) } label: {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(record.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                 ? "Geen locatie opgegeven" : record.locationName)
                                .font(FieldGuideTheme.sans(20, relativeTo: .title3))
                                .foregroundStyle(FieldGuideTheme.charcoal)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(record.historyDate())
                                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if ObservationCountry.foreignFlag(for: record.countryCode) != nil,
                           let code = ObservationCountry.normalized(record.countryCode) {
                            CountryFlagBadge(code: code, diameter: 36)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .contentShape(Rectangle())
                }.accessibilityHint("Open de kaart van deze waarneming")
                if record.id != records.last?.id {
                    Rectangle().fill(FieldGuideTheme.charcoal.opacity(0.10)).frame(height: 0.5)
                        .accessibilityHidden(true)
                }
            }
            if showsExport {
                Button("Exporteer alle waarnemingen (JSON)") {
                do { exportDocument = ObservationExport(data: try store.exportData()); exporting = true }
                catch { errorMessage = error.localizedDescription }
                }.frame(minHeight: 44).disabled(store.loadError != nil)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .padding(embedded ? 0 : 20)
        .frame(maxWidth: .infinity, alignment: .leading)
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
