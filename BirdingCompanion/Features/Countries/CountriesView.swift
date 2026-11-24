import SwiftUI

struct CountriesView: View {
    @EnvironmentObject private var store: ObservationStore
    @EnvironmentObject private var countryRepair: CountryRepairController
    @State private var showMap = false
    private var countries: [LoggedCountry] { CountryProjection.countries(in: store.observations) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                PageHeading(text: "Landen").accessibilityAddTraits(.isHeader).frame(maxWidth: .infinity, alignment: .leading)
                RoundAction(symbol: "map", label: "Bekijk eerste waarnemingen op de kaart") { showMap = true }
                    .disabled(store.loadError != nil)
            }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                .fixedSize(horizontal: false, vertical: true)
            CatalogResultsScroll(resetKey: "countries") {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if countryRepair.isWorking { ProgressView("Landen aanvullen…") }
                    if let message = countryRepair.errorMessage {
                        Text(message).font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                        Button("Probeer landen opnieuw aan te vullen") { countryRepair.retry(store: store) }
                    }
                    if let error = store.loadError { Text(error).foregroundStyle(.red) }
                    else if countries.isEmpty { Text("Nog geen landen met gelogde vogelsoorten.") }
                    ForEach(countries) { country in
                        NavigationLink(value: country) {
                            HStack(spacing: 16) {
                                CountryFlagBadge(code: country.code, diameter: 33.6).accessibilityHidden(true)
                                Text(country.name).font(FieldGuideTheme.sans(20, relativeTo: .title3)).frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(country.speciesCount) \(country.speciesCount == 1 ? "soort" : "soorten")").font(FieldGuideTheme.sans(14, relativeTo: .subheadline))
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .light))
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding(.horizontal, 20).padding(.bottom, 109)
            }
        }.background(FieldGuideTheme.ivory).toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showMap) { FirstObservationsMapView() }
            .navigationDestination(for: LoggedCountry.self) { country in LogbookView(countryCode: country.code) }
            .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
    }
}
