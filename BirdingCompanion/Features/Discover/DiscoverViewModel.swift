import Foundation
import Combine

@MainActor
final class DiscoverViewModel: ObservableObject {
    @Published private(set) var rows: [DiscoverSpecies] = []
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    @Published private(set) var attribution: String?
    @Published private(set) var isDemo = false
    @Published private(set) var loadedQuery: DiscoverQuery?
    private let repository: any DiscoverRepository
    private var requestID = UUID()

    init(repository: any DiscoverRepository = UnconfiguredDiscoverRepository()) {
        self.repository = repository
    }

    func load(query: DiscoverQuery, demo: Bool = false) async {
        let id = UUID()
        requestID = id
        rows = [] // Never leave another area's data under the new location heading.
        message = nil
        isLoading = true
        isDemo = false
        attribution = nil
        loadedQuery = nil
        defer { if requestID == id { isLoading = false } }
        do {
            let dataset: DiscoverDataset
            if demo { dataset = try await DemoDiscoverRepository().reports(for: query) }
            else { dataset = try await repository.reports(for: query) }
            guard requestID == id, !Task.isCancelled else { return }
            guard dataset.coversRequestedWindow else { throw DiscoverDataError.incompleteFeed }
            rows = DiscoverRanking.ranked(dataset.reports, query: query)
            isDemo = dataset.isDemo
            attribution = dataset.attribution
            loadedQuery = query
            isLoading = false
        } catch {
            guard requestID == id, !Task.isCancelled else { return }
            message = error is CancellationError ? nil : error.localizedDescription
            isLoading = false
        }
    }
}
