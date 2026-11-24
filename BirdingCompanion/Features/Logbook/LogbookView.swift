import SwiftUI

struct LogbookView: View {
    @EnvironmentObject private var store: ObservationStore
    @State private var sort: LogbookSort = .family
    @State private var showSearch = false
    @State private var search = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    var countryCode: String? = nil
    var catalog: [Species] = SpeciesGuideCatalog.species

    private var loggedRows: [LoggedSpecies] {
        LogbookProjection.species(observations: countryCode.map { CountryProjection.observations(in: $0, from: store.observations) } ?? store.observations, catalog: catalog, sort: sort)
    }
    private var rows: [LoggedSpecies] {
        let matches = Set(SpeciesCatalogSearch.results(for: search, in: loggedRows.map(\.species)).map(\.id))
        return loggedRows.filter { matches.contains($0.id) }
    }
    var body: some View {
        VStack(spacing: 0) {
            if let countryCode {
                CenteredPageHeader(title: ObservationCountry.name(for: countryCode), countryCode: countryCode) { dismiss() }
            }
            HStack(alignment: .top, spacing: 8) {
                ObservationTotal(value: loggedRows.count, label: "gelogde vogelsoorten")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    Picker("Sortering", selection: $sort) {
                        ForEach(LogbookSort.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 20, weight: .ultraLight))
                        .frame(width: 44, height: 44).background(FieldGuideTheme.searchControlBackground, in: Circle())
                }.accessibilityLabel("Sortering").accessibilityValue(sort.label)
                Button { showSearch.toggle() } label: {
                    Group {
                        if showSearch { Image(systemName: "xmark").font(.system(size: 22, weight: .ultraLight)) }
                        else { FineSearchMark().stroke(style: FieldGuideTheme.navigationStroke).frame(width: 22, height: 22) }
                    }.frame(width: 44, height: 44).background(FieldGuideTheme.searchControlBackground, in: Circle())
                }.accessibilityLabel(showSearch ? "Sluit zoeken in logboek" : "Zoek in je logboek")
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 16)
                .fixedSize(horizontal: false, vertical: true)
            if showSearch {
                BirdTextField("Zoek in je logboek", text: $search).modifier(RoundedSearchField())
                    .autocorrectionDisabled().focused($focused).padding(.horizontal, 20).padding(.bottom, 16)
            }
            CatalogResultsScroll(resetKey: "\(countryCode ?? "all")-\(sort.rawValue)-\(search)") {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if let loadError = store.loadError { Text(loadError).foregroundStyle(.red) }
                    else if loggedRows.isEmpty { Text("Nog geen vogelsoorten gelogd. Voeg je eerste waarneming toe met de plusknop.") }
                    else if rows.isEmpty { Text("Geen soorten gevonden in je logboek.") }
                    else if sort == .family {
                        ForEach(LogbookProjection.families(from: rows)) { group in
                            Section { speciesRows(group.species) } header: {
                                Text(group.family.dutchName.uppercased()).font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                                    .tracking(1).foregroundStyle(FieldGuideTheme.taupe)
                                    .padding(.horizontal, 12).padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FieldGuideTheme.beige.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                                    .padding(.top, 8).accessibilityAddTraits(.isHeader)
                            }
                        }
                    } else { speciesRows(rows) }
                }.padding(.horizontal, 20).padding(.bottom, 94)
            }
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .onChange(of: showSearch) { _, shown in focused = shown; if !shown { search = "" } }
    }

    private func speciesRows(_ species: [LoggedSpecies]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(species.enumerated()), id: \.element.id) { index, row in
                speciesRow(row)
                if index < species.count - 1 {
                    Rectangle().fill(FieldGuideTheme.charcoal.opacity(0.10))
                        .frame(height: 0.5)
                        .padding(.vertical, 3)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func speciesRow(_ row: LoggedSpecies) -> some View {
        NavigationLink(value: row.species) {
            HStack(spacing: 12) {
                PrimaryBirdArtwork(species: row.species).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    SerifText(row.species.dutchName, size: 16, relativeTo: .title3)
                    Text(row.species.englishDisplayName)
                        .font(FieldGuideTheme.sans(11.2, relativeTo: .subheadline))
                        .foregroundStyle(FieldGuideTheme.charcoal.opacity(0.7))
                    if row.species.scientificName.isEmpty {
                        Text(row.id).font(FieldGuideTheme.sans(12, relativeTo: .caption))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open de soortpagina met je waarnemingen")
    }
}
