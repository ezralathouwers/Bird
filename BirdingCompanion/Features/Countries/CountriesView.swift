import SwiftUI

struct CountriesView: View {
    @EnvironmentObject private var store: ObservationStore
    private var countries: [LoggedCountry] { CountryProjection.countries(in: store.observations) }
    private var unknownCount: Int {
        store.observations.filter { ObservationCountry.normalized($0.countryCode) == nil }.count
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("Landen").font(FieldGuideTheme.sans(34, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader)
                if let error = store.loadError { Text(error).foregroundStyle(.red) }
                else if countries.isEmpty { Text("Nog geen landen met gelogde vogelsoorten.") }
                ForEach(countries) { country in
                    NavigationLink(value: country) {
                        HStack(spacing: 16) {
                            Text(country.flag).font(.system(size: 30)).frame(width: 48, height: 48)
                                .background(FieldGuideTheme.beige.opacity(0.22), in: Circle()).accessibilityHidden(true)
                            Text(country.name).font(FieldGuideTheme.sans(20, relativeTo: .title3))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(country.speciesCount) \(country.speciesCount == 1 ? "soort" : "soorten")")
                                .font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
                        }.padding(.vertical, 12).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
                if unknownCount > 0 {
                    Text("\(unknownCount) waarnemingen hebben nog geen bekend land en zijn hier niet meegeteld.")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote)).foregroundStyle(FieldGuideTheme.taupe)
                }
            }.padding(20).padding(.bottom, 24)
        }
        .background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: LoggedCountry.self) { country in LogbookView(countryCode: country.code) }
        .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
    }
}
