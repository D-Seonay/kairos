#if DEBUG
import Foundation
import PulseDomain
import PulseServices
import SwiftUI

/// Les doublures des aperçus : quatre compléments en mémoire un vendredi à 9:00, la créatine déjà prise.
@MainActor
enum SupplementsPreviewSupport {
    static func model() -> SupplementsModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        let now = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 11, day: 20, hour: 9).date
            ?? .now
        let created = now.addingTimeInterval(-20 * 86_400)
        let creatine = Supplement(name: "Créatine", form: .powder, dose: 5, unit: .gram, timing: .fixedTime, timeOfDayMinutes: 480,
                                  days: .everyDay, stockDoses: 38, lowStockThreshold: 7, order: 0, createdAt: created,
                                  updatedAt: created)
        let vitamin = Supplement(name: "Vitamine D3", form: .capsule, dose: 1_000, unit: .iu, timing: .fixedTime,
                                 timeOfDayMinutes: 480, days: .everyDay, healthKitType: SupplementHealthType.vitaminD.rawValue,
                                 order: 1, createdAt: created, updatedAt: created)
        let caffeine = Supplement(name: "Caféine", form: .capsule, dose: 200, unit: .mg, timing: .beforeWorkout, days: .everyDay,
                                  order: 2, createdAt: created, updatedAt: created)
        let whey = Supplement(name: "Whey", form: .powder, dose: 30, unit: .gram, timing: .afterWorkout, days: .everyDay,
                              stockDoses: 4, lowStockThreshold: 7, healthKitType: SupplementHealthType.protein.rawValue, order: 3,
                              createdAt: created, updatedAt: created)
        let taken = SupplementIntake(supplementID: creatine.id, takenAt: now.addingTimeInterval(-3_600), dose: 5, createdAt: now,
                                     updatedAt: now)
        let repository = InMemorySupplementRepository(supplements: [creatine, vitamin, caffeine, whey], intakes: [taken])
        let service = SupplementService(supplements: repository, programs: InMemoryProgramRepository(),
                                        profiles: InMemoryProfileRepository(), workouts: InMemoryWorkoutRepository(),
                                        reminders: nil, health: nil, calendar: calendar, now: { now })
        return SupplementsModel(environment: SupplementsEnvironment(service: service,
                                                                    notifications: StubNotificationAuthorizer(granted: true),
                                                                    calendar: calendar, now: { now }))
    }
}

#Preview("Compléments") {
    NavigationStack {
        SupplementsView(model: SupplementsPreviewSupport.model())
    }
}

#Preview("Compléments, très grand texte") {
    NavigationStack {
        SupplementsView(model: SupplementsPreviewSupport.model())
    }
    .dynamicTypeSize(.accessibility3)
}

#Preview("Nouveau complément, très grand texte") {
    NavigationStack {
        SupplementFormView(model: SupplementsPreviewSupport.model(), editing: nil)
    }
    .dynamicTypeSize(.accessibility3)
}

#Preview("Carte de l'accueil, très grand texte") {
    let model = SupplementsPreviewSupport.model()
    SupplementsCard(model: model) {}
        .padding()
        .task { await model.load() }
        .dynamicTypeSize(.accessibility3)
}

#Preview("Carte de l'accueil") {
    let model = SupplementsPreviewSupport.model()
    SupplementsCard(model: model) {}
        .padding()
        .task { await model.load() }
}
#endif
