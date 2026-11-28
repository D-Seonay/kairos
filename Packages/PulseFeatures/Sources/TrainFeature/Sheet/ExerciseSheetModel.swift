import Foundation
import Observation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les trois onglets de la fiche exercice.
public enum ExerciseSheetTab: String, CaseIterable, Sendable {
    case technique
    case progression
    case alternatives
}

/// La fiche d'un exercice : technique, progression d'après l'historique et alternatives (spec M4 §10.2).
@MainActor
@Observable
public final class ExerciseSheetModel {
    /// Le nombre de séances de « Dernières séances ».
    private static let recentSessionCount = 10
    private static let chartDays = 90
    private static let changeDays = 30
    /// Niveaux de la carte musculaire : principaux au plus haut, secondaires à la moitié.
    private static let primaryWeight = 4.0
    private static let secondaryWeight = 2.0

    public let reference: ExerciseReference
    public var tab: ExerciseSheetTab = .technique
    public private(set) var info: ExerciseInfo?
    /// Pour un exercice perso, l'exercice lui-même, à modifier ou archiver.
    public private(set) var userExercise: UserExercise?
    public private(set) var painReminder: String?
    public private(set) var currentOneRepMax: Double?
    public private(set) var oneRepMaxChange30Days: Double?
    public private(set) var bestSet: BestSet?
    public private(set) var chart: [ChartPoint] = []
    public private(set) var recentSessions: [ExerciseHistoryLine] = []
    public private(set) var alternatives: [ExerciseInfo] = []
    /// Le plateau de l'exercice, s'il y en a un (fatigue et décharge écartées) ; `nil` sinon.
    public private(set) var plateau: ExercisePlateau?
    /// Une variante du même plan de mouvement faisable avec le matériel du profil, pour la piste du plateau.
    public private(set) var plateauVariant: ExerciseInfo?
    public private(set) var increment: Double = 2.5
    /// La note de la dernière séance avec l'exercice : la séance suivante la reprend sur la carte (« banc cran 3 »).
    public private(set) var pinnedNote: String?
    public private(set) var errorMessage: String?

    @ObservationIgnored private let environment: TrainEnvironment

    public init(environment: TrainEnvironment, reference: ExerciseReference) {
        self.environment = environment
        self.reference = reference
    }

    /// Relit l'exercice, le profil, les réglages, les records et l'historique. Si une lecture échoue, la fiche garde son dernier
    /// état et affiche une erreur.
    public func load() async {
        do {
            let userExercises = try await environment.userExercises.all(includeArchived: true)
            let directory = ExerciseDirectory(library: environment.library, userExercises: userExercises)
            let profile = try await environment.profiles.load()
            let settings = try await environment.exerciseSettings.settings(for: reference)
            let records = try await environment.personalRecords.records(for: reference)
            let sessions = try await environment.workouts.sessions(from: .distantPast, to: .distantFuture)
            info = directory.info(reference)
            userExercise = userExercises.first { .user(id: $0.id) == reference }
            alternatives = (info?.content?.alternatives ?? []).compactMap { directory.info(.content(id: $0)) }.filter(\.isActive)
            painReminder = painReminder(for: info, profile: profile)
            increment = info.map { IncrementResolver.increment(for: $0, settings: settings, profile: profile) } ?? increment
            currentOneRepMax = records.filter { $0.kind == .estimatedOneRepMax }.map(\.value).max()
            applyHistory(of: sessions)
            pinnedNote = sessions.filter { $0.status != .inProgress }.sorted { $0.startedAt > $1.startedAt }
                .lazy.compactMap { RecentExerciseSession($0, exercise: self.reference) }.first?.note
            plateau = PlateauDetector.plateau(for: reference, in: sessions, loadKind: info?.loadKind ?? .external,
                                              now: environment.now(), calendar: environment.calendar)
            plateauVariant = plateau == nil ? nil
                : ReplacementPlanner.alternatives(for: reference, directory: directory, profile: profile, excluding: []).first
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette fiche.", bundle: .module)
        }
    }

    /// Enregistre l'incrément de l'exercice, arrondi au quart de kilo entre 0,25 et 20 kg. Les autres réglages sont gardés.
    public func setIncrement(_ kg: Double) async {
        let previous = increment
        let clamped = IncrementStore.clamped(kg)
        increment = clamped
        do {
            try await IncrementStore(settings: environment.exerciseSettings).save(clamped, for: reference, now: environment.now())
            errorMessage = nil
        } catch {
            increment = previous
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer l'incrément.", bundle: .module)
        }
    }

    /// Les régions de la carte musculaire : principaux au niveau 4, secondaires au niveau 2.
    public var muscleLevels: [MuscleMapRegion: Int] {
        guard let info else { return [:] }
        var weights: [Muscle: Double] = [:]
        for muscle in info.secondaryMuscles { weights[muscle] = Self.secondaryWeight }
        for muscle in info.primaryMuscles { weights[muscle] = Self.primaryWeight }
        return MuscleIntensity.levels(weights: weights)
    }

    /// Le résumé de la courbe pour VoiceOver : nombre de séances, premier et dernier point, en mots. `nil` sans point.
    public var chartSummary: String? {
        guard let first = chart.first, let last = chart.last else { return nil }
        let sessions = TrainText.sessions(chart.count)
        let start = pointText(first)
        let name = Self.oneRepMaxName
        guard chart.count > 1 else { return String(localized: "\(name), \(sessions) : \(start).", bundle: .module) }
        return String(localized: "\(name), \(sessions) : \(start), puis \(pointText(last)).", bundle: .module)
    }

    /// Le graphique audio de la courbe : axe des dates, axe du maximum estimé en kilos et une série ; `nil` sans point.
    public var chartDescriptor: PulseChartDescriptor? {
        guard let summary = chartSummary else { return nil }
        let values = chart.map(\.value)
        let (low, high) = (values.min() ?? 0, values.max() ?? 0)
        let name = Self.oneRepMaxName
        return PulseChartDescriptor(
            title: name, summary: summary, xAxis: .dates(title: String(localized: "Date", bundle: .module)),
            yAxis: .init(title: String(localized: "\(name), en kilos", bundle: .module), unit: String(localized: "kilos", bundle: .module),
                         range: low < high ? low...high : (low - 1)...(high + 1), valueText: { PulseSpoken.kilos(Self.rounded($0)) }),
            series: [.init(name: name, points: chart.map { .init(date: $0.date, y: $0.value) })], calendar: environment.calendar)
    }

    /// Un point de la courbe dit en mots : la date « 26 octobre » et la valeur « 80 kilos ».
    public func pointSpoken(_ point: ChartPoint) -> (label: String, value: String) {
        (PulseSpoken.date(point.date, calendar: environment.calendar), PulseSpoken.kilos(Self.rounded(point.value)))
    }

    /// « Maximum estimé sur une répétition » : le 1RM, dit en mots.
    static var oneRepMaxName: String {
        String(localized: "Maximum estimé sur une répétition", bundle: .module)
    }

    /// « 80 kilos » ; « aucune valeur » sans séance de charge.
    public var oneRepMaxSpokenText: String {
        currentOneRepMax.map { PulseSpoken.kilos(Self.rounded($0)) } ?? String(localized: "aucune valeur", bundle: .module)
    }

    /// « en hausse de 2,5 kilos en 30 jours », « en baisse de 2 kilos en 30 jours », « inchangé en 30 jours » ; `nil` sans séance
    /// d'il y a 30 jours ou plus.
    public var oneRepMaxChangeSpokenText: String? {
        guard let change = oneRepMaxChange30Days else { return nil }
        let kilos = PulseSpoken.kilos(Self.rounded(abs(change)))
        if Self.rounded(change) > 0 { return String(localized: "en hausse de \(kilos) en 30 jours", bundle: .module) }
        if Self.rounded(change) < 0 { return String(localized: "en baisse de \(kilos) en 30 jours", bundle: .module) }
        return String(localized: "inchangé en 30 jours", bundle: .module)
    }

    /// « 72,5 kilos, 5 répétitions » ; « aucune série » sans série.
    public var bestSetSpokenText: String {
        bestSet?.spokenText ?? String(localized: "aucune série", bundle: .module)
    }

    private nonisolated static func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func pointText(_ point: ChartPoint) -> String {
        String(localized: "\(PulseSpoken.kilos(Self.rounded(point.value))) le \(dateText(point.date))", bundle: .module)
    }

    /// « 26 octobre », dans le calendrier de l'environnement.
    public func dateText(_ date: Date) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "fr_FR"),
                                     calendar: environment.calendar, timeZone: environment.calendar.timeZone)
        return date.formatted(style.day().month(.wide))
    }

    /// Le calendrier de l'environnement, pour les dates du texte du plateau.
    var calendar: Calendar { environment.calendar }

    /// Le modèle de la fiche d'un autre exercice, par exemple une alternative.
    public func sheet(for reference: ExerciseReference) -> ExerciseSheetModel {
        ExerciseSheetModel(environment: environment, reference: reference)
    }

    /// Le formulaire de modification de l'exercice perso ; `nil` pour un exercice du contenu.
    public func editor() -> CustomExerciseModel? {
        userExercise.map { CustomExerciseModel(environment: environment, draft: nil, editing: $0) }
    }

    // MARK: - Interne

    private func applyHistory(of sessions: [WorkoutSession]) {
        let now = environment.now()
        let history = ExerciseHistory(sessions: sessions, exercise: reference, loadKind: info?.loadKind ?? .external)
        chart = day(offset: -Self.chartDays, from: now).map(history.chart(since:)) ?? []
        recentSessions = history.lines(limit: Self.recentSessionCount)
        bestSet = history.bestSet
        oneRepMaxChange30Days = day(offset: -Self.changeDays, from: now)
            .flatMap(history.bestEstimate(before:))
            .flatMap { baseline in currentOneRepMax.map { $0 - baseline } }
    }

    private func day(offset: Int, from date: Date) -> Date? {
        environment.calendar.date(byAdding: .day, value: offset, to: date)
    }

    /// Les zones à risque de l'exercice que l'utilisateur a déclarées douloureuses, en une phrase ; `nil` sans recoupement.
    private func painReminder(for info: ExerciseInfo?, profile: UserProfile?) -> String? {
        let risks = Set(info?.content?.riskAreas ?? [])
        let areas = PainArea.allCases.filter { risks.contains($0) && (profile?.painAreas.contains($0) ?? false) }
        guard !areas.isEmpty else { return nil }
        let names = areas.map(\.reminderName).formatted(.list(type: .and).locale(Locale(identifier: "fr_FR")))
        return String(localized: "Tu as signalé : \(names). Cet exercice peut les solliciter : ajuste la charge ou prends une alternative.",
                      bundle: .module)
    }
}

private extension PainArea {
    /// La zone en toutes lettres, au pluriel et en minuscules, pour une phrase.
    var reminderName: String {
        switch self {
        case .shoulders: String(localized: "épaules", bundle: .module)
        case .lowerBack: String(localized: "lombaires", bundle: .module)
        case .knees: String(localized: "genoux", bundle: .module)
        case .wrists: String(localized: "poignets", bundle: .module)
        }
    }
}
