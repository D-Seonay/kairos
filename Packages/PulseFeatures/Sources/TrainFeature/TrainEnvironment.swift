import Foundation
import PulseContent
import PulseDomain
import PulseServices

/// Tout ce dont l'onglet « Séance » a besoin du dehors : le profil et son programme, les scores enregistrés, les séances,
/// les exercices et leurs réglages, les records, l'import Hevy, le contenu, la séance en cours et l'horloge.
public struct TrainEnvironment: Sendable {
    public var profiles: any ProfileRepository
    public var programs: any ProgramRepository
    public var recovery: any RecoveryRepository
    public var workouts: any WorkoutRepository
    public var userExercises: any UserExerciseRepository
    public var exerciseSettings: any ExerciseSettingsRepository
    public var personalRecords: any PersonalRecordRepository
    public var records: RecordsService
    public var importer: HevyImporter
    public var library: ContentLibrary
    public var activeSession: ActiveSessionService
    /// La semaine datée : ses déplacements changent la séance du jour (spec M6 §4) ; `nil` : la semaine type seule.
    public var scheduledDays: (any ScheduledDayRepository)?
    /// Les photos des séances ; `nil` : aucune section Photos (aperçus, tests, séances sans photos).
    public var sessionPhotos: SessionPhotoService?
    public var calendar: Calendar
    public var now: @Sendable () -> Date

    public init(profiles: any ProfileRepository, programs: any ProgramRepository, recovery: any RecoveryRepository,
                workouts: any WorkoutRepository, userExercises: any UserExerciseRepository,
                exerciseSettings: any ExerciseSettingsRepository, personalRecords: any PersonalRecordRepository,
                records: RecordsService, importer: HevyImporter, library: ContentLibrary,
                activeSession: ActiveSessionService, scheduledDays: (any ScheduledDayRepository)? = nil, calendar: Calendar,
                now: @escaping @Sendable () -> Date, sessionPhotos: SessionPhotoService? = nil) {
        self.profiles = profiles
        self.programs = programs
        self.recovery = recovery
        self.workouts = workouts
        self.userExercises = userExercises
        self.exerciseSettings = exerciseSettings
        self.personalRecords = personalRecords
        self.records = records
        self.importer = importer
        self.library = library
        self.activeSession = activeSession
        self.scheduledDays = scheduledDays
        self.sessionPhotos = sessionPhotos
        self.calendar = calendar
        self.now = now
    }
}
