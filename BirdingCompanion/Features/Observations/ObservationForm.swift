import SwiftUI

struct ObservationForm: View {
    let species: Species
    private let original: Observation?
    @EnvironmentObject private var store: ObservationStore
    @Environment(\.dismiss) private var dismiss
    @State private var observedAt: Date
    @State private var locationName: String
    @State private var count: Int
    @State private var notes: String
    @State private var confirmed: Bool
    @State private var captive: Bool
    @State private var errorMessage: String?

    init(species: Species, observation: Observation? = nil) {
        self.species = species
        original = observation
        _observedAt = State(initialValue: observation?.observedAt ?? Date())
        _locationName = State(initialValue: observation?.locationName ?? "")
        _count = State(initialValue: observation?.count ?? 1)
        _notes = State(initialValue: observation?.notes ?? "")
        _confirmed = State(initialValue: observation?.status != .uncertain)
        _captive = State(initialValue: observation?.isCaptive ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(species.dutchName) {
                    DatePicker("Datum en tijd", selection: $observedAt)
                    TextField("Locatie (optioneel)", text: $locationName)
                    Stepper("Aantal: \(count)", value: $count, in: 1...99999)
                    Toggle("Identificatie bevestigd", isOn: $confirmed)
                    Toggle("In gevangenschap", isOn: $captive)
                    TextField("Notities", text: $notes, axis: .vertical).lineLimit(3...8)
                }
                Section {
                    Text("Lokaal opgeslagen op dit apparaat. Alleen bevestigde waarnemingen van vrije vogels tellen standaard mee voor je lifelijst.")
                        .font(FieldGuideTheme.sans(13, relativeTo: .footnote))
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).accessibilityLabel("Opslaan mislukt: \(errorMessage)") }
            }
            .navigationTitle(original == nil ? "Waarneming toevoegen" : "Waarneming bewerken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuleren") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") { save() }.disabled(store.loadError != nil)
                }
            }
        }
    }

    private func save() {
        var record = original ?? Observation(speciesID: species.id, taxonomyVersion: species.taxonomyVersion,
            observedAt: observedAt, locationName: locationName, count: count, notes: notes,
            status: confirmed ? .confirmed : .uncertain)
        record.observedAt = observedAt
        record.locationName = locationName
        record.count = count
        record.notes = notes
        record.status = confirmed ? .confirmed : .uncertain
        record.isCaptive = captive
        do { try store.save(record, editing: original != nil); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
