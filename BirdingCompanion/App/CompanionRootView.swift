import SwiftUI
import AVFoundation

private enum MainSection: String {
    case discover = "Ontdek", identify = "Identificeer", sessions = "Sessies", goals = "Doelstellingen", countries = "Landen", list = "Logboek"
}

struct CompanionRootView: View {
    @EnvironmentObject private var store: ObservationStore
    @StateObject private var sessionLogger = SessionLiveLogger()
    @StateObject private var soundModel = SoundIdentificationModel()
    @StateObject private var soundPins = SoundResultPins()
    @State private var identificationPath = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLiveSession = false
    @StateObject private var observationNavigation = ObservationNavigation()
    @State private var section: MainSection = .discover
    @State private var speciesPath: [Species] = []
    @State private var logbookPath: [Species] = []
    @StateObject private var discover = DiscoverViewModel()
    @State private var showAddMenu = false
    @State private var showLaunchLogo = true
    @State private var plusCenter = CGPoint.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let addButtonDiameter: CGFloat = 64 * 0.9
    // The button's center (and plus crossbar) sits on the navigation's top edge.
    private var addButtonOverlap: CGFloat { addButtonDiameter / 2 }
    private var addSymbolDiameter: CGFloat { showAddMenu ? 40 * 0.9 : 36 * 0.9 }
    private let species = MockSpeciesRepository.kingfisher

    var body: some View {
        ZStack {
            content
                .opacity(observationNavigation.selection == nil && !showLiveSession ? 1 : 0)
                .allowsHitTesting(observationNavigation.selection == nil && !showLiveSession && !showAddMenu)
                .accessibilityHidden(observationNavigation.selection != nil || showLiveSession || showAddMenu)
            if showAddMenu {
                AddEntryView(isPresented: $showAddMenu, onLiveStarted: { showLiveSession = true })
                    .ignoresSafeArea()
                    .transition(reduceMotion ? .opacity : .modifier(
                        active: CircularMenuReveal(progress: 0, origin: plusCenter),
                        identity: CircularMenuReveal(progress: 1, origin: plusCenter)))
                    .zIndex(2)
            } else if showLiveSession {
                LiveSessionView(isPresented: $showLiveSession, onFinished: { showLiveSession = false; section = .sessions })
            }
        }
            .environment(\.speciesAudioIsAllowed,
                         observationNavigation.selection == nil && !showLiveSession && !showAddMenu
                            && !soundModel.isRecording && !soundModel.isStarting)
            .environmentObject(observationNavigation)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FieldGuideTheme.ivory.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: -addButtonOverlap) { bottomNavigation }
            .environmentObject(sessionLogger)
            .environmentObject(soundModel)
            .environmentObject(soundPins)
            .onChange(of: soundModel.startedAt) { _, _ in soundPins.reset() }
            .onChange(of: scenePhase) { _, phase in if phase == .background { soundModel.stop() } }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in soundModel.stop() }
            .coordinateSpace(name: "appRoot")
            .onPreferenceChange(PlusCenterPreference.self) { value in Task { @MainActor in plusCenter = value } }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: showAddMenu)
            .overlay {
                if showLaunchLogo {
                    FieldGuideTheme.navigationOlive.ignoresSafeArea()
                        .overlay {
                            NavigationOutlineMark(kind: .bird).stroke(FieldGuideTheme.ivory,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                .frame(width: 88, height: 88).accessibilityLabel("Birder")
                        }.transition(.opacity)
                }
            }
            .task {
                async let location: Void = SharedCurrentLocation.shared.prewarmIfAuthorized()
                try? await Task.sleep(for: .seconds(1))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { showLaunchLogo = false }
                await location
            }
            .fullScreenCover(item: $observationNavigation.selection) { observation in
                ObservationMapView(observation: observation, species: observationNavigation.species ?? species)
                    .environmentObject(store)
            }
    }

    @ViewBuilder private var content: some View {
        switch section {
        case .discover:
            NavigationStack(path: $speciesPath) {
                DiscoverView(model: discover)
                    .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
            }
        case .identify:
            NavigationStack(path: $identificationPath) {
                IdentificationView()
                    .navigationDestination(for: IdentificationRoute.self) { route in
                        switch route {
                        case .photo: PhotoIdentificationView()
                        case .audio: SoundIdentificationView()
                        }
                    }
            }
        case .sessions:
            NavigationStack {
                SessionsView(showLive: $showLiveSession)
            }
        case .goals:
            NavigationStack { GoalsView() }
        case .countries:
            NavigationStack { CountriesView() }
        case .list:
            NavigationStack(path: $logbookPath) {
                LogbookView()
                    .navigationDestination(for: Species.self) { bird in SpeciesDetailView(species: bird) }
            }
        }
    }

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            // Negative inset spacing lets habitat extend behind this reserved hit area.
            Color.clear.frame(height: addButtonOverlap).allowsHitTesting(false)
            if showAddMenu {
                Color.clear.frame(height: 60).allowsHitTesting(false)
            } else {
                GeometryReader { geometry in
                    // Equal slots within each group; keep 44-point targets on
                    // small phones and reserve a wider gap around the plus.
                    let centerGap = max(56, min(84, geometry.size.width - 6 * 44))
                    HStack(spacing: centerGap) {
                        HStack(spacing: 0) {
                            navigationItem(.discover)
                            navigationItem(.identify)
                            navigationItem(.sessions)
                        }.frame(maxWidth: .infinity)
                        HStack(spacing: 0) {
                            navigationItem(.goals)
                            navigationItem(.countries)
                            navigationItem(.list)
                        }.frame(maxWidth: .infinity)
                    }
                }
                // Bound the reader so safeAreaInset cannot consume the page.
                .frame(height: 56)
                .padding(.top, 4)
                .background(FieldGuideTheme.navigationWhite.ignoresSafeArea(edges: .bottom))
            }
        }
        .overlay(alignment: .top) {
            Button {
                if showAddMenu { showAddMenu = false }
                else if store.activeSession != nil {
                    observationNavigation.selection = nil
                    showAddMenu = false
                    showLiveSession = true
                } else {
                    showAddMenu.toggle()
                }
            } label: {
                Group {
                    if store.activeSession != nil && !showAddMenu {
                        NavigationOutlineMark(kind: .play).stroke(style: FieldGuideTheme.navigationStroke)
                            .foregroundStyle(FieldGuideTheme.ivory)
                            .frame(width: 36, height: 36)
                    } else {
                        FinePlusMark()
                            .stroke(showAddMenu ? FieldGuideTheme.charcoal : FieldGuideTheme.ivory,
                                    style: FieldGuideTheme.navigationStroke)
                            .rotationEffect(.degrees(showAddMenu ? 45 : 0))
                            .frame(width: addSymbolDiameter, height: addSymbolDiameter)
                    }
                }
                    .frame(width: addButtonDiameter, height: addButtonDiameter)
                    .background(showAddMenu ? FieldGuideTheme.beige :
                        (store.activeSession != nil ? FieldGuideTheme.khaki :
                        FieldGuideTheme.charcoal), in: Circle())
                    .contentShape(Circle())
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: PlusCenterPreference.self,
                        value: CGPoint(x: geometry.frame(in: .global).midX,
                                       y: geometry.frame(in: .global).midY))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showAddMenu ? "Sluit toevoegopties" : (store.activeSession != nil ? "Open livesessie" : "Open toevoegopties"))
            .accessibilityHint(showAddMenu ? "Terug naar de vorige pagina" : (store.activeSession != nil ? "Terug naar de actieve vogelsessie" : "Voeg een waarneming, sessie of doelstelling toe"))
        }
    }

    private func navigationItem(_ item: MainSection) -> some View {
        Button {
            observationNavigation.selection = nil
            showLiveSession = false
            showAddMenu = false
            if item == .identify {
                identificationPath = soundModel.isRecording || soundModel.isStarting
                    ? NavigationPath([IdentificationRoute.audio]) : NavigationPath()
            }
            if item == .discover { speciesPath.removeAll() }
            if item == .list { logbookPath.removeAll() }
            section = item
        } label: {
            Group {
                if item == .goals {
                    ZStack {
                        GoalListMark().stroke(style: FieldGuideTheme.navigationStroke)
                        GoalCompletionDot().fill(FieldGuideTheme.charcoal)
                    }.frame(width: 24, height: 24)
                } else if item == .countries {
                    SimpleGlobeMark().stroke(style: FieldGuideTheme.navigationStroke)
                        .frame(width: 24, height: 24)
                } else {
                    NavigationOutlineMark(kind: item == .discover ? .binoculars :
                        (item == .identify ? .viewfinder : (item == .sessions ? .clock : .bird)))
                        .stroke(style: FieldGuideTheme.navigationStroke)
                        .frame(width: item == .discover ? 22.032 * 1.1 : (item == .list ? 21.6 * 1.1 : 24),
                               height: item == .discover ? 22.032 * 1.1 : (item == .list ? 21.6 * 1.1 : 24))
                }
            }
            .frame(minWidth: 44, maxWidth: .infinity, minHeight: 56, maxHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.rawValue)
        .accessibilityAddTraits(section == item ? [.isSelected] : [])
        .foregroundStyle(section == item ? FieldGuideTheme.navigationOlive : FieldGuideTheme.charcoal)
    }
}

// Two spaced rows, with a small completion dot inside the first open circle.
private struct GoalListMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for y in [5.5, 18.5] {
            path.addEllipse(in: CGRect(x: 1.3, y: y - 3.1, width: 6.2, height: 6.2))
            path.move(to: CGPoint(x: 11, y: y))
            path.addLine(to: CGPoint(x: 23, y: y))
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

private struct GoalCompletionDot: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 3, y: 4.1, width: 2.8, height: 2.8))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

// Curved meridians only; omit the straight vertical center line.
private struct SimpleGlobeMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: 1, y: 1, width: 22, height: 22))
        path.addEllipse(in: CGRect(x: 8, y: 1, width: 8, height: 22))
        path.move(to: CGPoint(x: 1, y: 12))
        path.addLine(to: CGPoint(x: 23, y: 12))
        path.move(to: CGPoint(x: 2.2, y: 7))
        path.addQuadCurve(to: CGPoint(x: 21.8, y: 7), control: CGPoint(x: 12, y: 10))
        path.move(to: CGPoint(x: 2.2, y: 17))
        path.addQuadCurve(to: CGPoint(x: 21.8, y: 17), control: CGPoint(x: 12, y: 14))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

// Explicit hairline glyph: the circle behind this mark intentionally has no stroke.
private struct FinePlusMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}


// Shared vector outlines let all icons use exactly the same stroke, including
// at the slightly smaller binocular/bird sizes. Shapes scale before stroking.
struct NavigationOutlineMark: Shape {
    enum Kind { case binoculars, viewfinder, clock, bird, play }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch kind {
        case .binoculars:
            path.addEllipse(in: CGRect(x: 1, y: 12, width: 9.2, height: 9.2))
            path.addEllipse(in: CGRect(x: 13.8, y: 12, width: 9.2, height: 9.2))
            path.move(to: CGPoint(x: 1.3, y: 15))
            path.addLine(to: CGPoint(x: 4.2, y: 4.2))
            path.addQuadCurve(to: CGPoint(x: 8.6, y: 4.2), control: CGPoint(x: 6.4, y: 0.5))
            path.addLine(to: CGPoint(x: 10.2, y: 16.6))
            path.move(to: CGPoint(x: 13.8, y: 16.6))
            path.addLine(to: CGPoint(x: 15.4, y: 4.2))
            path.addQuadCurve(to: CGPoint(x: 19.8, y: 4.2), control: CGPoint(x: 17.6, y: 0.5))
            path.addLine(to: CGPoint(x: 22.7, y: 15))
            path.move(to: CGPoint(x: 9.5, y: 10))
            path.addQuadCurve(to: CGPoint(x: 14.5, y: 10), control: CGPoint(x: 12, y: 8))
            path.move(to: CGPoint(x: 10.2, y: 15))
            path.addLine(to: CGPoint(x: 13.8, y: 15))
        case .viewfinder:
            for (x, y, dx, dy) in [(2.0, 2.0, 1.0, 1.0), (22, 2, -1, 1),
                                   (2, 22, 1, -1), (22, 22, -1, -1)] {
                path.move(to: CGPoint(x: x + 5 * dx, y: y))
                path.addLine(to: CGPoint(x: x + 2 * dx, y: y))
                path.addQuadCurve(to: CGPoint(x: x, y: y + 2 * dy), control: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x, y: y + 5 * dy))
            }
        case .clock:
            path.addEllipse(in: CGRect(x: 1, y: 1, width: 22, height: 22))
            path.move(to: CGPoint(x: 12, y: 4))
            path.addLine(to: CGPoint(x: 12, y: 12))
            path.addLine(to: CGPoint(x: 18, y: 12))
        case .bird:
            path.move(to: CGPoint(x: 14, y: 9))
            path.addCurve(to: CGPoint(x: 9, y: 1), control1: CGPoint(x: 15, y: 5), control2: CGPoint(x: 11, y: 2))
            path.addQuadCurve(to: CGPoint(x: 8, y: 10), control: CGPoint(x: 7, y: 5))
            path.addQuadCurve(to: CGPoint(x: 1, y: 7), control: CGPoint(x: 4, y: 7))
            path.addQuadCurve(to: CGPoint(x: 8, y: 15), control: CGPoint(x: 2, y: 12))
            path.addLine(to: CGPoint(x: 5, y: 22))
            path.addQuadCurve(to: CGPoint(x: 13, y: 18), control: CGPoint(x: 11, y: 23))
            path.addQuadCurve(to: CGPoint(x: 18, y: 12), control: CGPoint(x: 16, y: 17))
            path.addLine(to: CGPoint(x: 23, y: 10))
            path.addLine(to: CGPoint(x: 19, y: 9))
            path.addQuadCurve(to: CGPoint(x: 14, y: 9), control: CGPoint(x: 17, y: 5))
            path.closeSubpath()
        case .play:
            path.move(to: CGPoint(x: 6, y: 3))
            path.addLine(to: CGPoint(x: 21, y: 12))
            path.addLine(to: CGPoint(x: 6, y: 21))
            path.closeSubpath()
        }
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

private struct PlusCenterPreference: PreferenceKey {
    static let defaultValue = CGPoint.zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { value = nextValue() }
}
private struct CircularMenuReveal: AnimatableModifier {
    // SwiftUI interpolates this value through Animatable's nonisolated contract.
    // Keep the plain value storage and its accessor outside the UI actor.
    nonisolated var progress: CGFloat
    let origin: CGPoint
    nonisolated var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func body(content: Content) -> some View {
        content.mask {
            GeometryReader { geometry in
                let frame = geometry.frame(in: .global)
                Path(ellipseIn: MenuRevealGeometry.circle(globalOrigin: origin, maskFrame: frame, progress: progress))
                    .fill(.black)
            }
        }
    }
}

// The mask and button are measured in one screen coordinate space, including
// status-bar and navigation safe areas. The circle center never interpolates.
enum MenuRevealGeometry {
    static func circle(globalOrigin: CGPoint, maskFrame: CGRect, progress: CGFloat) -> CGRect {
        let center = globalOrigin == .zero ? CGPoint(x: maskFrame.width / 2, y: maskFrame.height)
            : CGPoint(x: globalOrigin.x - maskFrame.minX, y: globalOrigin.y - maskFrame.minY)
        let distance = hypot(max(center.x, maskFrame.width - center.x), max(center.y, maskFrame.height - center.y))
        let radius = 28.8 + max(0, distance - 28.8) * min(1, max(0, progress))
        return CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
