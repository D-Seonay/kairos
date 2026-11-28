import Foundation
import PulseDomain

/// Les compléments du jour, vus par l'écran Compléments, la carte de l'accueil et celle du récap.
public struct SupplementOverview: Sendable, Equatable {
    /// Minuit local du jour lu.
    public var day: Date
    /// Les compléments dus ce jour-là, par moment puis par heure.
    public var items: [SupplementDueItem]
    /// Tous les compléments non archivés, par ordre, dus ou non ce jour-là.
    public var supplements: [Supplement]
    public var regularity: [UUID: SupplementRegularity]
    public var advice: [SupplementAdvice]
    /// Les compléments archivés, par ordre : ils peuvent revenir dans la liste.
    public var archived: [Supplement]
    /// L'heure habituelle d'endormissement, en minutes après minuit ; `nil` sous 5 nuits dans les 14 derniers jours.
    public var habitualBedtimeMinutes: Int?
    /// Les compléments « au coucher » qui suivent les nuits, pour l'interrupteur du formulaire.
    public var followingNights: Set<UUID>

    public init(day: Date, items: [SupplementDueItem], supplements: [Supplement], regularity: [UUID: SupplementRegularity],
                advice: [SupplementAdvice], archived: [Supplement] = [], habitualBedtimeMinutes: Int? = nil,
                followingNights: Set<UUID> = []) {
        self.day = day
        self.items = items
        self.supplements = supplements
        self.regularity = regularity
        self.advice = advice
        self.archived = archived
        self.habitualBedtimeMinutes = habitualBedtimeMinutes
        self.followingNights = followingNights
    }

    public static func empty(day: Date) -> SupplementOverview {
        SupplementOverview(day: day, items: [], supplements: [], regularity: [:], advice: [])
    }

    public var takenCount: Int { items.filter(\.isTaken).count }
    public var dueCount: Int { items.count }

    /// La prochaine prise : le premier complément dû et non pris, par heure prévue puis par ordre.
    public var next: SupplementDueItem? {
        items.filter { !$0.isTaken }.min { lhs, rhs in
            lhs.plannedMinutes != rhs.plannedMinutes ? lhs.plannedMinutes < rhs.plannedMinutes
                : lhs.supplement.order < rhs.supplement.order
        }
    }

    /// Les compléments dont le stock suivi est au seuil d'alerte ou en dessous.
    public var lowStock: [Supplement] {
        supplements.filter(\.isLowOnStock)
    }

    /// Les compléments « autour de la séance » du jour, pour la carte du récap.
    public var workoutItems: [SupplementDueItem] {
        items.filter { $0.moment == .workout }
    }
}

extension Supplement {
    /// Le stock est suivi, a un seuil, et l'atteint.
    public var isLowOnStock: Bool {
        guard let stockDoses, let lowStockThreshold else { return false }
        return stockDoses <= lowStockThreshold
    }
}

/// Le seul chemin vers les compléments (spec M5 §5) : lecture du jour, enregistrement, prise et décoche avec le stock et Apple
/// Santé, rappels. Les prises et décoches passent l'une après l'autre par une même file : une notification et l'écran ne
/// comptent jamais une prise deux fois.
public final class SupplementService: Sendable {
    /// Les prises non écrites dans Apple Santé sont réessayées sur 7 jours.
    static let healthRetryDays = 7

    private let supplements: any SupplementRepository
    private let programs: any ProgramRepository
    private let profiles: any ProfileRepository
    private let workouts: any WorkoutRepository
    /// La semaine datée : un déplacement du Planning change les jours d'entraînement des compléments (spec M6 §4).
    private let scheduledDays: (any ScheduledDayRepository)?
    private let reminders: (any SupplementReminderScheduling)?
    private let health: (any SupplementHealthWriting)?
    /// L'heure habituelle d'endormissement, lue dans le cache local d'Apple Santé ; `nil` : les compléments « au coucher » gardent
    /// leur heure fixe.
    private let bedtime: HabitualBedtimeReader?
    /// « Suivre mes nuits », par complément et par appareil.
    private let bedtimeStore: (any SupplementBedtimeStore)?
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let queue = SerialTaskQueue()

    public init(supplements: any SupplementRepository, programs: any ProgramRepository, profiles: any ProfileRepository,
                workouts: any WorkoutRepository, reminders: (any SupplementReminderScheduling)?,
                health: (any SupplementHealthWriting)?, scheduledDays: (any ScheduledDayRepository)? = nil,
                bedtime: HabitualBedtimeReader? = nil, bedtimeStore: (any SupplementBedtimeStore)? = nil, calendar: Calendar,
                now: @escaping @Sendable () -> Date) {
        self.supplements = supplements
        self.programs = programs
        self.profiles = profiles
        self.workouts = workouts
        self.scheduledDays = scheduledDays
        self.reminders = reminders
        self.health = health
        self.bedtime = bedtime
        self.bedtimeStore = bedtimeStore
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Lecture

    /// Les compléments d'aujourd'hui, leur régularité et les conseils.
    public func overview() async throws -> SupplementOverview {
        let schedule = try await loadSchedule()
        let today = calendar.startOfDay(for: now())
        let items = schedule.items(on: today)
        let regularity = Dictionary(uniqueKeysWithValues: schedule.supplements.map {
            ($0.id, SupplementRegularity.compute(for: $0, schedule: schedule, today: today))
        })
        let archived = try await supplements.supplements(includeArchived: true).filter(\.isArchived)
        return SupplementOverview(day: today, items: items, supplements: schedule.supplements, regularity: regularity,
                                  advice: SupplementCatalog.advice(for: items), archived: archived,
                                  habitualBedtimeMinutes: schedule.habitualBedtimeMinutes,
                                  followingNights: schedule.followingNights)
    }

    // MARK: - Enregistrement

    /// Enregistre le complément, créé ou modifié, et replanifie les rappels. `followsNights` règle « Suivre mes nuits » sur cet
    /// appareil (vrai seulement pour un complément « au coucher ») ; `nil` le laisse tel quel.
    public func save(_ supplement: Supplement, followsNights: Bool? = nil) async throws {
        var stamped = supplement
        stamped.updatedAt = now()
        try await supplements.save(stamped)
        // Après l'enregistrement : un échec ne laisse pas le réglage changé pour un complément resté tel quel.
        if let followsNights {
            bedtimeStore?.setFollowsNights(followsNights && supplement.timing == .bedtime, for: supplement.id)
        }
        await rescheduleReminders()
    }

    /// Archive le complément : il sort de la liste et des rappels, ses prises restent dans l'export.
    public func archive(id: UUID) async throws {
        try await setArchived(true, id: id)
    }

    /// Désarchive le complément : il revient dans la liste à sa place, et ses rappels sont replanifiés comme à la création.
    public func unarchive(id: UUID) async throws {
        try await setArchived(false, id: id)
    }

    private func setArchived(_ isArchived: Bool, id: UUID) async throws {
        guard var supplement = try await supplements.supplements(includeArchived: true).first(where: { $0.id == id }),
              supplement.isArchived != isArchived else { return }
        supplement.isArchived = isArchived
        try await save(supplement)
    }

    /// L'ordre d'un nouveau complément : après le dernier.
    public func nextOrder() async throws -> Int {
        (try await supplements.supplements(includeArchived: true).map(\.order).max() ?? -1) + 1
    }

    // MARK: - Prise

    /// Coche le complément pour `day` (aujourd'hui par défaut). Faux s'il était déjà pris ce jour-là ou n'existe plus. La prise
    /// est horodatée maintenant, ou à la dernière minute du jour quand l'action d'un rappel de la veille arrive après minuit.
    @discardableResult
    public func take(supplementID: UUID, day: Date? = nil) async throws -> Bool {
        let taken = try await queue.run { try await self.recordIntake(supplementID: supplementID, day: day) }
        if taken { await rescheduleReminders() }
        return taken
    }

    /// Décoche le complément pour `day` : la dernière prise du jour est supprimée, avec son échantillon Apple Santé, et le
    /// stock remonte d'une dose.
    public func untake(supplementID: UUID, day: Date? = nil) async throws {
        let removed = try await queue.run { try await self.removeIntake(supplementID: supplementID, day: day) }
        if removed { await rescheduleReminders() }
    }

    private func recordIntake(supplementID: UUID, day: Date?) async throws -> Bool {
        let now = now()
        let dayStart = calendar.startOfDay(for: day ?? now)
        guard var supplement = try await supplements.supplements(includeArchived: true).first(where: { $0.id == supplementID }),
              let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        let existing = try await supplements.intakes(from: dayStart, to: dayEnd)
        guard !existing.contains(where: { $0.supplementID == supplementID }) else { return false }
        let takenAt = now >= dayStart && now < dayEnd ? now : min(now, dayEnd.addingTimeInterval(-60))
        var intake = SupplementIntake(supplementID: supplementID, takenAt: takenAt, dose: supplement.dose, createdAt: now,
                                      updatedAt: now)
        try await supplements.save(intake)
        if let stock = supplement.stockDoses {
            supplement.stockDoses = max(0, stock - 1)
            supplement.updatedAt = now
            try await supplements.save(supplement)
        }
        if let written = await writeToHealth(intake, of: supplement) {
            intake = written
            try await supplements.save(intake)
        }
        return true
    }

    private func removeIntake(supplementID: UUID, day: Date?) async throws -> Bool {
        let now = now()
        let dayStart = calendar.startOfDay(for: day ?? now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let intake = try await supplements.intakes(from: dayStart, to: dayEnd)
                .filter({ $0.supplementID == supplementID }).max(by: { $0.takenAt < $1.takenAt }) else { return false }
        try await supplements.delete(intakeID: intake.id)
        if var supplement = try await supplements.supplements(includeArchived: true).first(where: { $0.id == supplementID }),
           let stock = supplement.stockDoses {
            supplement.stockDoses = stock + 1
            supplement.updatedAt = now
            try await supplements.save(supplement)
        }
        if let health, let sample = intake.healthKitUUID.flatMap(UUID.init(uuidString:)) {
            // L'échantillon a pu être supprimé dans l'app Santé : la prise est décochée quoi qu'il arrive.
            do {
                try await health.deleteSupplementSample(id: sample)
            } catch {
                logger.failure("Prise de complément non retirée d'Apple Santé", error)
            }
        }
        return true
    }

    // MARK: - Apple Santé

    public func healthAccess() async -> HealthWriteAccess {
        await health?.supplementWriteAccess() ?? .unavailable
    }

    /// Montre la demande système si elle n'a jamais été faite.
    public func requestHealthAccess() async -> HealthWriteAccess {
        await health?.requestSupplementWriteAccess() ?? .unavailable
    }

    /// Réécrit les prises des 7 derniers jours qu'Apple Santé n'a pas reçues (iPhone verrouillé à la prise).
    public func retryHealthWrites() async {
        guard let health, await health.supplementWriteAccess() == .authorized else { return }
        try? await queue.run {
            let now = self.now()
            guard let start = self.calendar.date(byAdding: .day, value: -Self.healthRetryDays, to: now) else { return }
            let pending = try await self.supplements.intakes(from: start, to: now.addingTimeInterval(1)).filter { !$0.writtenToHealthKit }
            guard !pending.isEmpty else { return }
            let byID = Dictionary(try await self.supplements.supplements(includeArchived: true).map { ($0.id, $0) },
                                  uniquingKeysWith: { first, _ in first })
            for intake in pending {
                guard let supplement = byID[intake.supplementID],
                      let written = await self.writeToHealth(intake, of: supplement) else { continue }
                try await self.supplements.save(written)
            }
        }
    }

    /// La prise marquée écrite, ou `nil` quand rien n'est à écrire (pas de type, unité non convertible, pas d'accès) ou que
    /// l'écriture échoue.
    private func writeToHealth(_ intake: SupplementIntake, of supplement: Supplement) async -> SupplementIntake? {
        guard let health, let type = supplement.healthType,
              let amount = SupplementHealthDose.amount(dose: intake.dose, unit: supplement.unit, type: type),
              await health.supplementWriteAccess() == .authorized else { return nil }
        let id: UUID
        do {
            id = try await health.save(SupplementHealthEntry(intakeID: intake.id, type: type, amount: amount, date: intake.takenAt))
        } catch {
            logger.failure("Prise de complément non écrite dans Apple Santé", error)
            return nil
        }
        var written = intake
        written.writtenToHealthKit = true
        written.healthKitUUID = id.uuidString
        written.updatedAt = now()
        return written
    }

    // MARK: - Rappels

    /// Recalcule tous les rappels des 14 prochains jours. Une lecture qui échoue laisse les rappels en place.
    public func rescheduleReminders() async {
        guard let reminders, let schedule = try? await loadSchedule() else { return }
        let enabled = (try? await profiles.load())?.supplementRemindersEnabled ?? true
        await reminders.replaceSupplementReminders(with: SupplementReminderPlanner.reminders(schedule: schedule, now: now(),
                                                                                             enabled: enabled))
    }

    // MARK: - Interne

    /// Les compléments, les prises des 30 derniers jours, les jours d'entraînement du programme actif avec les déplacements de la
    /// semaine datée sur la régularité et les rappels, les séances des 60 derniers jours, et l'heure habituelle d'endormissement
    /// des 14 dernières nuits (recalculée à chaque fois, jamais enregistrée).
    private func loadSchedule() async throws -> SupplementSchedule {
        let now = now()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let intakesStart = calendar.date(byAdding: .day, value: -SupplementRegularity.windowDays, to: today) ?? today
        let sessionsStart = calendar.date(byAdding: .day, value: -SupplementSchedule.habitualWindowDays, to: today) ?? today
        let profile = try await profiles.load()
        let program = try await profile?.activeProgramID.asyncFlatMap { try await programs.program(id: $0) }
        return SupplementSchedule(supplements: try await supplements.supplements(includeArchived: false),
                                  intakes: try await supplements.intakes(from: intakesStart, to: tomorrow),
                                  trainingWeekdays: SupplementSchedule.trainingWeekdays(of: program),
                                  plannedTrainingDays: SupplementSchedule.plannedTrainingDays(
                                      of: program, overrides: await overrides(from: intakesStart, today: today), calendar: calendar),
                                  sessions: try await workouts.sessions(from: sessionsStart, to: tomorrow),
                                  habitualBedtimeMinutes: await bedtime?.minutes(now: now),
                                  followingNights: bedtimeStore?.followingNights ?? [], calendar: calendar)
    }
}

extension SupplementService {
    /// Les lignes de la semaine datée de `from` à la fin de l'horizon des rappels ; aucune si leur lecture échoue : les jours
    /// suivent alors la semaine type.
    private func overrides(from start: Date, today: Date) async -> [ScheduledDay] {
        guard let scheduledDays,
              let end = calendar.date(byAdding: .day, value: SupplementReminderPlanner.horizonDays + 1, to: today) else { return [] }
        return (try? await scheduledDays.days(from: start, to: end)) ?? []
    }
}

private extension Optional {
    func asyncFlatMap<T>(_ transform: (Wrapped) async throws -> T?) async rethrows -> T? {
        guard let value = self else { return nil }
        return try await transform(value)
    }
}
