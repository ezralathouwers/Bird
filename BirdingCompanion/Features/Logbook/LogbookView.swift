import SwiftUI
import UniformTypeIdentifiers

struct LogbookView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var sort: LogbookSort = .family
    @State private var exporting = false
    @State private var exportDocument = ObservationExport(data: Data())
    @State private var errorMessage: String?
    var catalog: [Species] = DiscoverFixtures.catalog

    private var rows: [LoggedSpecies] {
        LogbookProjection.species(observations: store.observations, catalog: catalog, sort: sort)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("\(rows.count)").font(FieldGuideTheme.sans(34, relativeTo: .largeTitle))
                    .accessibilityLabel("\(rows.count) gelogde vogelsoorten")
                    .accessibilityAddTraits(.isHeader)
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Picker("Sortering", selection: $sort) {
                        ForEach(LogbookSort.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minHeight: 44)
                    .accessibilityHint("Per familie groepeert je soorten. Laatst gelogd toont een doorlopende lijst.")
                }
                if let loadError = store.loadError {
                    Text(loadError).foregroundStyle(.red)
                } else if rows.isEmpty {
                    Text("Nog geen vogelsoorten gelogd. Voeg je eerste waarneming toe met de plusknop.")
                        .font(FieldGuideTheme.sans())
                } else if sort == .family {
                    ForEach(LogbookProjection.families(from: rows)) { group in
                        Section {
                            speciesRows(group.species)
                        } header: {
                            Text(group.family.dutchName.uppercased())
                                .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                .tracking(1)
                                .foregroundStyle(FieldGuideTheme.taupe)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(FieldGuideTheme.beige.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                                .padding(.top, 11)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                } else {
                    speciesRows(rows)
                }
                Button("Exporteer alle waarnemingen (JSON)") {
                    do { exportDocument = ObservationExport(data: try store.exportData()); exporting = true }
                    catch { errorMessage = error.localizedDescription }
                }
                .frame(minHeight: 44)
                .disabled(store.loadError != nil)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .padding(20).padding(.bottom, 24)
        }
        .background(FieldGuideTheme.ivory)
        .toolbar(.hidden, for: .navigationBar)
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json,
                      defaultFilename: "birding-waarnemingen") { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
    }

    private func speciesRows(_ species: [LoggedSpecies]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(species.enumerated()), id: \.element.id) { index, row in
                speciesRow(row)
                if index < species.count - 1 {
                    Rectangle().fill(FieldGuideTheme.charcoal.opacity(0.10))
                        .frame(height: 0.5).accessibilityHidden(true)
                }
            }
        }
    }

    private func speciesRow(_ row: LoggedSpecies) -> some View {
        NavigationLink(value: row.species) {
            HStack(spacing: 16) {
                PrimaryBirdArtwork(species: row.species).frame(width: 104, height: 104)
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.species.dutchName).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                    Text(row.species.englishDisplayName)
                        .font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                        .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                    if row.species.scientificName.isEmpty {
                        Text(row.id).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open de soortpagina met je waarnemingen")
    }
}
