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
    private static let incrementRange = 0.25...20.0
    private static let incrementStep = 0.25
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
    public private(set) var increment: Double = 2.5
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
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu lire cette fiche.", bundle: .module)
        }
    }

    /// Enregistre l'incrément de l'exercice, arrondi au quart de kilo entre 0,25 et 20 kg. Les autres réglages sont gardés.
    public func setIncrement(_ kg: Double) async {
        let previous = increment
        let clamped = min(max((kg / Self.incrementStep).rounded() * Self.incrementStep, Self.incrementRange.lowerBound),
                          Self.incrementRange.upperBound)
        increment = clamped
        let now = environment.now()
        do {
            var settings = try await environment.exerciseSettings.settings(for: reference)
                ?? ExerciseSettings(exercise: reference, createdAt: now, updatedAt: now)
            settings.incrementKg = clamped
            settings.updatedAt = now
            try await environment.exerciseSettings.save(settings)
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

    /// Le résumé de la courbe pour VoiceOver : nombre de séances, premier et dernier point. `nil` sans point.
    public var chartSummary: String? {
        guard let first = chart.first, let last = chart.last else { return nil }
        let sessions = String(localized: "\(chart.count) séances", bundle: .module)
        let start = pointText(first)
        guard chart.count > 1 else { return String(localized: "1RM estimé, \(sessions) : \(start).", bundle: .module) }
        return String(localized: "1RM estimé, \(sessions) : \(start), puis \(pointText(last)).", bundle: .module)
    }

    private func pointText(_ point: ChartPoint) -> String {
        let value = PulseFormat.decimal(point.value, maxFractionDigits: 1)
        return String(localized: "\(value) kg le \(dateText(point.date))", bundle: .module)
    }

    /// « 26 octobre », dans le calendrier de l'environnement.
    public func dateText(_ date: Date) -> String {
        let style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "fr_FR"),
                                     calendar: environment.calendar, timeZone: environment.calendar.timeZone)
        return date.formatted(style.day().month(.wide))
    }

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
