import Foundation

struct BirdFamily: Identifiable, Hashable, Sendable {
    let id: String
    let dutchName: String

    static func displayFamily(id: String, englishName: String) -> BirdFamily {
        let friendly = commonNames[id] ?? (englishName.isEmpty ? "Overige vogels" : englishName)
        return BirdFamily(id: id, dutchName: friendly)
    }
    private static let commonNames: [String: String] = [
        "Acrocephalidae": "Rietzangers",
        "Prionopidae": "Helmklauwieren",
        "Panuridae": "Baardmannetjes",
        "Accipitridae": "Haviken en arenden",
        "Aegithalidae": "Staartmezen",
        "Aegithinidae": "Iora's",
        "Aegothelidae": "Uilnachtzwaluwen",
        "Alaudidae": "Leeuweriken",
        "Alcedinidae": "IJsvogels",
        "Alcidae": "Alken",
        "Anatidae": "Eenden, ganzen en zwanen",
        "Anhingidae": "Slangenhalsvogels",
        "Apodidae": "Gierzwaluwen",
        "Apterygidae": "Kiwi's",
        "Aramidae": "Koerlans",
        "Ardeidae": "Reigers",
        "Artamidae": "Spitsvogels en verwanten",
        "Atrichornithidae": "Struikvogels",
        "Balaenicipitidae": "Schoenbekken",
        "Bombycillidae": "Pestvogels",
        "Brachypteraciidae": "Grondscharrelaars",
        "Bucconidae": "Baardkoekoeken",
        "Bucerotidae": "Neushoornvogels",
        "Burhinidae": "Grielen",
        "Cacatuidae": "Kaketoes",
        "Calcariidae": "IJsgorzen en sneeuwgorzen",
        "Campephagidae": "Rupsvogels",
        "Capitonidae": "Amerikaanse baardvogels",
        "Caprimulgidae": "Nachtzwaluwen",
        "Cardinalidae": "Kardinalen",
        "Cariamidae": "Seriema's",
        "Casuariidae": "Emoes en kasuarissen",
        "Cathartidae": "Amerikaanse gieren",
        "Certhiidae": "Boomkruipers",
        "Cettiidae": "Struikzangers",
        "Charadriidae": "Plevieren",
        "Chloropseidae": "Bladvogels",
        "Ciconiidae": "Ooievaars",
        "Cinclidae": "Waterspreeuwen",
        "Cisticolidae": "Graszangers",
        "Climacteridae": "Australische boomkruipers",
        "Coliidae": "Muisvogels",
        "Columbidae": "Duiven",
        "Coraciidae": "Scharrelaars",
        "Corcoracidae": "Moddernestbouwers",
        "Corvidae": "Kraaien",
        "Cotingidae": "Cotinga's",
        "Cracidae": "Hokko's en goeanen",
        "Cuculidae": "Koekoeken",
        "Dasyornithidae": "Borstelvogels",
        "Dicaeidae": "Bastaardhoningvogels",
        "Dicruridae": "Drongo's",
        "Diomedeidae": "Albatrossen",
        "Dromadidae": "Krabplevieren",
        "Elachuridae": "Elachura's",
        "Emberizidae": "Gorzen",
        "Estrildidae": "Prachtvinken",
        "Eupetidae": "Ralbabbelaren",
        "Eurylaimidae": "Breedbekken",
        "Falconidae": "Valken",
        "Formicariidae": "Mierlijsters",
        "Fregatidae": "Fregatvogels",
        "Fringillidae": "Vinken",
        "Furnariidae": "Ovenvogels",
        "Galbulidae": "Glansvogels",
        "Gaviidae": "Duikers",
        "Glareolidae": "Renvogels en vorkstaartplevieren",
        "Grallariidae": "Mierpitta's",
        "Gruidae": "Kraanvogels",
        "Haematopodidae": "Scholeksters",
        "Heliornithidae": "Fuutkoeten",
        "Hemiprocnidae": "Boomgierzwaluwen",
        "Hirundinidae": "Zwaluwen",
        "Hydrobatidae": "Noordelijke stormvogeltjes",
        "Ibidorhynchidae": "Ibissnavels",
        "Icteridae": "Amerikaanse troepialen",
        "Indicatoridae": "Honingspeurders",
        "Jacanidae": "Jacana's",
        "Laniidae": "Klauwieren",
        "Laridae": "Meeuwen en sterns",
        "Leiothrichidae": "Lijstergaaien en verwanten",
        "Leptosomidae": "Koerol's",
        "Locustellidae": "Sprinkhaanzangers",
        "Lybiidae": "Afrikaanse baardvogels",
        "Malaconotidae": "Bosklauwieren",
        "Maluridae": "Elfjes",
        "Megalaimidae": "Aziatische baardvogels",
        "Megapodiidae": "Grootpoothoenders",
        "Meliphagidae": "Honingeters",
        "Menuridae": "Liervogels",
        "Meropidae": "Bijeneters",
        "Mesitornithidae": "Steltrallen",
        "Mimidae": "Spotlijsters",
        "Monarchidae": "Monarchvliegenvangers",
        "Motacillidae": "Kwikstaarten en piepers",
        "Muscicapidae": "Vliegenvangers",
        "Musophagidae": "Toerako's",
        "Nectariniidae": "Honingzuigers",
        "Notiomystidae": "Stichbirds",
        "Numididae": "Parelhoenders",
        "Oceanitidae": "Zuidelijke stormvogeltjes",
        "Odontophoridae": "Amerikaanse kwartels",
        "Opisthocomidae": "Hoatzins",
        "Oriolidae": "Wielewalen",
        "Otididae": "Trappen",
        "Oxyruncidae": "Scherpsnavels",
        "Pandionidae": "Visarenden",
        "Paradisaeidae": "Paradijsvogels",
        "Paridae": "Mezen",
        "Parulidae": "Amerikaanse zangers",
        "Passerellidae": "Amerikaanse gorzen",
        "Passeridae": "Mussen",
        "Pelecanidae": "Pelikanen",
        "Pellorneidae": "Jungletimalia's",
        "Petroicidae": "Australische vliegenvangers",
        "Phaethontidae": "Keerkringvogels",
        "Phalacrocoracidae": "Aalscholvers",
        "Phasianidae": "Fazanten en hoenders",
        "Phoenicopteridae": "Flamingo's",
        "Phoeniculidae": "Boomhoppen",
        "Phylloscopidae": "Boszangers",
        "Picidae": "Spechten",
        "Pipridae": "Manakins",
        "Pittidae": "Pitta's",
        "Ploceidae": "Wevers",
        "Podargidae": "Kikkerbekken",
        "Podicipedidae": "Futen",
        "Polioptilidae": "Muggenvangers",
        "Procellariidae": "Stormvogels en pijlstormvogels",
        "Prunellidae": "Heggenmussen",
        "Psittacidae": "Amerikaanse en Afrikaanse papegaaien",
        "Psittaculidae": "Aziatische en Australische papegaaien",
        "Psophiidae": "Trompetvogels",
        "Psophodidae": "Zwiepvogels",
        "Pteroclidae": "Zandhoenders",
        "Pycnonotidae": "Buulbuuls",
        "Rallidae": "Rallen en koeten",
        "Recurvirostridae": "Kluten en stelten",
        "Regulidae": "Goudhanen",
        "Remizidae": "Buidelmezen",
        "Rheidae": "Nandoes",
        "Rhinocryptidae": "Tapaculo's",
        "Rhipiduridae": "Waaierstaarten",
        "Rhynochetidae": "Kagoes",
        "Rostratulidae": "Goudsnippen",
        "Sagittariidae": "Secretarisvogels",
        "Scolopacidae": "Strandlopers en snippen",
        "Scopidae": "Hamerkoppen",
        "Sittidae": "Boomklevers",
        "Spheniscidae": "Pinguïns",
        "Stenostiridae": "Elfvliegenvangers",
        "Stercorariidae": "Jagers",
        "Strigidae": "Uilen",
        "Struthionidae": "Struisvogels",
        "Sturnidae": "Spreeuwen",
        "Sulidae": "Genten",
        "Sylviidae": "Grasmussen en verwanten",
        "Thamnophilidae": "Miervogels",
        "Thraupidae": "Tangaren",
        "Threskiornithidae": "Ibissen en lepelaars",
        "Timaliidae": "Timalia's",
        "Tinamidae": "Tinamoe's",
        "Tityridae": "Tityra's en verwanten",
        "Todidae": "Todies",
        "Trochilidae": "Kolibries",
        "Troglodytidae": "Winterkoningen",
        "Trogonidae": "Trogons",
        "Turdidae": "Lijsters",
        "Turnicidae": "Vechtkwartels",
        "Tyrannidae": "Tirannen",
        "Tytonidae": "Kerkuilen",
        "Upupidae": "Hoppen",
        "Vangidae": "Vanga's",
        "Viduidae": "Wida's en staalvinken",
        "Vireonidae": "Vireo's",
        "Zosteropidae": "Brilvogels",
    ]

    static let thrushes = BirdFamily(id: "Turdidae", dutchName: "Lijsters")
    static let tits = BirdFamily(id: "Paridae", dutchName: "Mezen")
    static let flycatchers = BirdFamily(id: "Muscicapidae", dutchName: "Vliegenvangers")
    static let woodpeckers = BirdFamily(id: "Picidae", dutchName: "Spechten")
    static let kingfishers = BirdFamily(id: "Alcedinidae", dutchName: "IJsvogels")
    static let unknown = BirdFamily(id: "unclassified", dutchName: "Familie onbekend")
}

enum LogbookSort: String, CaseIterable {
    case family, lastLogged
    var label: String { self == .family ? "Per familie" : "Laatst ontdekt" }
}

struct LoggedSpecies: Identifiable, Sendable {
    let species: Species
    let firstObservedAt: Date
    var id: String { species.id }
}

struct LoggedFamily: Identifiable, Sendable {
    let family: BirdFamily
    let species: [LoggedSpecies]
    var id: String { family.id }
}

struct LogbookProjection {
    static func species(observations: [Observation], catalog: [Species], sort: LogbookSort) -> [LoggedSpecies] {
        var earliest: [String: Observation] = [:]
        for observation in observations {
            if let existing = earliest[observation.speciesID], existing.observedAt <= observation.observedAt { continue }
            earliest[observation.speciesID] = observation
        }
        let known = catalog.reduce(into: [String: Species]()) { $0[$1.id] = $1 }
        return earliest.values.map { record in
            let bird = known[record.speciesID] ?? BirdNETSpeciesLookup.species(id: record.speciesID) ?? Species(id: record.speciesID, taxonomyVersion: record.taxonomyVersion,
                dutchName: "Onbekende soort", englishName: "Unknown species", scientificName: "")
            return LoggedSpecies(species: bird, firstObservedAt: record.observedAt)
        }.sorted {
            if sort == .lastLogged, $0.firstObservedAt != $1.firstObservedAt { return $0.firstObservedAt > $1.firstObservedAt }
            return nameComesBefore($0.species, $1.species)
        }
    }

    static func families(from rows: [LoggedSpecies]) -> [LoggedFamily] {
        let grouped = Dictionary(grouping: rows) { $0.species.family ?? .unknown }
        return grouped.map { family, birds in
            LoggedFamily(family: family, species: birds.sorted { nameComesBefore($0.species, $1.species) })
        }.sorted {
            if $0.family == .unknown { return false }
            if $1.family == .unknown { return true }
            let comparison = $0.family.dutchName.compare($1.family.dutchName,
                options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    private static func nameComesBefore(_ left: Species, _ right: Species) -> Bool {
        let comparison = left.dutchName.compare(right.dutchName,
            options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "nl_BE"))
        return comparison == .orderedSame ? left.id < right.id : comparison == .orderedAscending
    }
}
