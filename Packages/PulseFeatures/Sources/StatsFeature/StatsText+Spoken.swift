import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain
import PulseServices

/// Ce que la VFC et la FC au repos disent d'elles-mêmes : leur nom et leur unité en toutes lettres.
enum BiometricMeasure {
    case hrv
    case restingHeartRate

    /// « Variabilité et ligne de base », « Fréquence cardiaque au repos » : le nom dit, sans « FC ».
    var spokenName: String {
        switch self {
        case .hrv: String(localized: "Variabilité et ligne de base", bundle: .module)
        case .restingHeartRate: String(localized: "Fréquence cardiaque au repos", bundle: .module)
        }
    }

    /// « 56 millisecondes », « 1 battement par minute » : la valeur arrondie, l'unité au singulier jusqu'à 1.
    func spoken(_ value: Double) -> String {
        guard value.isFinite, abs(value) < 1e9 else { return "\u{2014}" }
        let rounded = Int(value.rounded())
        switch self {
        case .hrv:
            return PulseSpoken.count(rounded, singular: String(localized: "milliseconde", bundle: .module),
                                     plural: String(localized: "millisecondes", bundle: .module))
        case .restingHeartRate:
            return PulseSpoken.count(rounded, singular: String(localized: "battement par minute", bundle: .module),
                                     plural: String(localized: "battements par minute", bundle: .module))
        }
    }

    /// « Variabilité, en millisecondes » : le titre de l'axe vertical.
    var axisTitle: String {
        switch self {
        case .hrv: String(localized: "Variabilité, en millisecondes", bundle: .module)
        case .restingHeartRate: String(localized: "Fréquence cardiaque au repos, en battements par minute", bundle: .module)
        }
    }
}

/// Les textes dits par VoiceOver : records, assiduité, résumés de graphiques et valeurs de chaque marque. Des fonctions pures,
/// testées : jamais « kg », « ms », « bpm », « reps », « 1RM » ni un mois abrégé, les durées en toutes lettres.
extension StatsText {
    // MARK: Dates

    /// « 28 octobre », ou « 28 octobre 2025 » hors de l'année de `today` : la date en toutes lettres.
    static func spokenDate(_ date: Date, calendar: Calendar, today: Date) -> String {
        let day = PulseSpoken.date(date, calendar: calendar)
        let year = calendar.component(.year, from: date)
        guard year != calendar.component(.year, from: today) else { return day }
        return "\(day) \(year)"
    }

    /// « 12 novembre » par jour, « Semaine du 9 novembre » par semaine : le grain d'un point ou d'une barre.
    static func bucketLabel(_ date: Date, bucket: StatsBucket, calendar: Calendar) -> String {
        let day = PulseSpoken.date(date, calendar: calendar)
        return bucket == .day ? day : String(localized: "Semaine du \(day)", bundle: .module)
    }

    /// « Nuit » par jour, « Semaine » par semaine : le nom de l'axe des dates des courbes de nuits.
    static func nightAxisName(_ bucket: StatsBucket) -> String {
        bucket == .day ? String(localized: "Nuit", bundle: .module) : String(localized: "Semaine", bundle: .module)
    }

    /// « Nuit du 12 novembre » par jour, « Semaine du 9 novembre » par semaine.
    static func nightLabel(_ date: Date, bucket: StatsBucket, calendar: Calendar) -> String {
        guard bucket == .day else { return bucketLabel(date, bucket: bucket, calendar: calendar) }
        return String(localized: "Nuit du \(PulseSpoken.date(date, calendar: calendar))", bundle: .module)
    }

    // MARK: Records

    /// « 24 minutes 31 », « 1 heure 45 minutes 7 » : un temps de course dit en durée, pas en heure.
    static func raceTimeSpoken(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < 1e12 else { return dash }
        return PulseSpoken.duration(seconds: Int(seconds.rounded()))
    }

    /// « Squat : 96 kilos, maximum estimé sur une répétition, série de 85 kilos pour 5 répétitions, le 28 octobre, plus 2,5
    /// kilos. » La valeur d'abord ; « nouveau » à la place de l'écart quand le record est le premier.
    static func strengthRecordSpoken(_ line: StrengthRecordLine, calendar: Calendar, today: Date) -> String {
        var parts: [String] = []
        let isReps = line.kind == .repsAtWeight
        if isReps {
            parts.append(PulseSpoken.repetitions(Int(line.value.rounded())))
        } else {
            parts.append(PulseSpoken.kilos(rounded(line.value)))
            parts.append(String(localized: "maximum estimé sur une répétition", bundle: .module))
        }
        if let weight = line.weightKg, weight > 0, let reps = line.reps {
            parts.append(String(localized: "série de \(PulseSpoken.kilos(weight)) pour \(PulseSpoken.repetitions(reps))", bundle: .module))
        }
        let date = spokenDate(line.date, calendar: calendar, today: today)
        parts.append(String(localized: "le \(date)", bundle: .module))
        if let gain = line.gain, gain > 0 {
            let amount = isReps ? PulseSpoken.repetitions(Int(gain.rounded())) : PulseSpoken.kilos(rounded(gain))
            parts.append(String(localized: "plus \(amount)", bundle: .module))
        } else if line.isNew {
            parts.append(String(localized: "nouveau", bundle: .module))
        }
        let details = parts.joined(separator: ", ")
        return String(localized: "\(line.name) : \(details).", bundle: .module)
    }

    /// « 5 kilomètres : 24 minutes 31, nouveau, allure moyenne de la sortie du 14 septembre. » ; « … : pas encore couru. »
    static func runRecordSpoken(_ run: RunBest, calendar: Calendar, today: Date) -> String {
        let title = distanceSpoken(run.distance)
        guard let seconds = run.seconds else {
            return String(localized: "\(title) : pas encore couru.", bundle: .module)
        }
        var parts = [raceTimeSpoken(seconds: seconds)]
        if run.isNew { parts.append(String(localized: "nouveau", bundle: .module)) }
        if let date = run.date {
            let day = spokenDate(date, calendar: calendar, today: today)
            parts.append(String(localized: "allure moyenne de la sortie du \(day)", bundle: .module))
        }
        let details = parts.joined(separator: ", ")
        return String(localized: "\(title) : \(details).", bundle: .module)
    }

    static func distanceSpoken(_ distance: RunDistance) -> String {
        switch distance {
        case .fiveK: String(localized: "5 kilomètres", bundle: .module)
        case .tenK: String(localized: "10 kilomètres", bundle: .module)
        case .half: String(localized: "Semi-marathon", bundle: .module)
        }
    }

    /// Une décimale au plus : « 96,4 », comme à l'écran.
    private static func rounded(_ value: Double) -> Double { (value * 10).rounded() / 10 }

    // MARK: Assiduité

    /// « Semaine du 3 novembre » ; « Semaine en cours, du 3 novembre » pour la dernière colonne.
    static func attendanceWeekLabel(week: [AttendanceDay], isCurrent: Bool, calendar: Calendar) -> String {
        let monday = week.first.map { dayMonth($0.date, calendar: calendar) } ?? ""
        return isCurrent
            ? String(localized: "Semaine en cours, du \(monday)", bundle: .module)
            : String(localized: "Semaine du \(monday)", bundle: .module)
    }

    /// « 4 jours d'entraînement : lundi, mercredi, vendredi, samedi » ; « aucun jour d'entraînement ». La valeur d'une colonne
    /// de la grille : quels jours, et pas seulement combien.
    static func attendanceDays(week: [AttendanceDay], calendar: Calendar) -> String {
        let trained = week.filter { $0.level > 0 && !$0.isFuture }
        switch trained.count {
        case 0:
            return String(localized: "aucun jour d'entraînement", bundle: .module)
        case let count:
            let days = trained.map { PulseSpoken.weekday($0.date, calendar: calendar) }.joined(separator: ", ")
            let total = count == 1
                ? String(localized: "1 jour d'entraînement", bundle: .module)
                : String(localized: "\(count) jours d'entraînement", bundle: .module)
            return String(localized: "\(total) : \(days)", bundle: .module)
        }
    }

    // MARK: Noms

    static var strengthName: String { String(localized: "Musculation", bundle: .module) }
    static var runName: String { String(localized: "Course", bundle: .module) }
    static var rideName: String { String(localized: "Vélo", bundle: .module) }

    /// « Charge par jour » sur 7 jours, « Charge par semaine » au-delà.
    static func loadTitle(_ bucket: StatsBucket) -> String {
        bucket == .day ? String(localized: "Charge par jour", bundle: .module) : String(localized: "Charge par semaine", bundle: .module)
    }

    // MARK: Tuiles

    /// « Fréquence cardiaque au repos, 58 battements par minute, plus 6 % par rapport aux 30 jours précédents » : le titre, la
    /// valeur et les précisions dits ; sans valeur, « Pas assez de données » et la raison.
    static func tileSpoken(_ content: StatsTileContent) -> String {
        let title = content.spokenTitle ?? content.title
        guard let value = content.value else { return [title, content.emptyTitle, content.emptyReason].joined(separator: ", ") }
        return ([title, content.spokenValue ?? value] + (content.spokenDetails ?? content.details)).joined(separator: ", ")
    }

    /// « +6 % par rapport aux 30 jours précédents », « +6 % par rapport à l'année précédente » sur un an ; `nil` sans période
    /// précédente. Écrit et dit de la même façon.
    static func comparisonSpoken(_ comparison: StatsComparison?, days: Int) -> String? {
        change(comparison).map { change in
            days == StatsPeriod.year.days
                ? String(localized: "\(change) par rapport à l'année précédente", bundle: .module)
                : String(localized: "\(change) par rapport aux \(days) jours précédents", bundle: .module)
        }
    }

    // MARK: Résumés de graphique

    /// « Ratio aigu sur chronique, 30 jours : dernier 1,12, de 0,86 à 1,31. Zone optimale de 0,8 à 1,3, risque à 1,5. »
    static func ratioSummary(points: [StatsPoint], period: StatsPeriod) -> String {
        let values = points.map(\.value)
        func text(_ value: Double?) -> String { PulseFormat.decimal(value ?? .nan, maxFractionDigits: 2) }
        let title = period.title
        let (last, low, high) = (text(values.last), text(values.min()), text(values.max()))
        return String(localized: """
            Ratio aigu sur chronique, \(title) : dernier \(last), de \(low) à \(high). Zone optimale de 0,8 à 1,3, risque à 1,5.
            """, bundle: .module)
    }

    /// « Charge, 30 jours : 8 450 en tout, dont musculation 5 200, course 2 650, vélo 600. »
    static func loadSummary(totals: LoadTotals, period: StatsPeriod) -> String {
        let title = period.title
        let all = number(totals.totalLoad)
        let (strength, run, ride) = (number(totals.strengthLoad), number(totals.runLoad), number(totals.rideLoad))
        return String(localized: """
            Charge, \(title) : \(all) en tout, dont musculation \(strength), course \(run), vélo \(ride).
            """, bundle: .module)
    }

    /// « Variabilité et ligne de base, 30 jours : moyenne 56 millisecondes, de 42 à 70 millisecondes, ligne de base 54
    /// millisecondes. » Sans point, « Pas assez de données » se dit par le descripteur.
    static func baselineSummary(measure: BiometricMeasure, points: [BaselinePoint], period: StatsPeriod) -> String {
        let values = points.map(\.value)
        let baselines = points.compactMap(\.baseline)
        let name = measure.spokenName
        let title = period.title
        let average = measure.spoken(values.isEmpty ? .nan : values.reduce(0, +) / Double(values.count))
        let low = PulseFormat.integer(values.min() ?? .nan, unit: nil)
        let high = measure.spoken(values.max() ?? .nan)
        var text = String(localized: "\(name), \(title) : moyenne \(average), de \(low) à \(high)", bundle: .module)
        if !baselines.isEmpty {
            let baseline = measure.spoken(baselines.reduce(0, +) / Double(baselines.count))
            text += String(localized: ", ligne de base \(baseline)", bundle: .module)
        }
        return text + "."
    }

    /// « Sommeil, 30 jours : 7 heures 12 minutes en moyenne, profond 19 %, nuit la plus courte 5 heures 30 minutes le 3
    /// novembre, nuit la plus longue 9 heures le 5 novembre. »
    static func sleepSummary(points: [SleepPoint], deepShare: Double?, period: StatsPeriod, bucket: StatsBucket,
                             calendar: Calendar) -> String {
        let title = period.title
        let minutes = points.map(\.asleepMinutes)
        let average = durationSpoken(minutes: minutes.isEmpty ? .nan : minutes.reduce(0, +) / Double(minutes.count))
        var text = String(localized: "Sommeil, \(title) : \(average) en moyenne", bundle: .module)
        if let deepShare {
            text += String(localized: ", profond \(PulseFormat.integer(deepShare * 100, unit: "%"))", bundle: .module)
        }
        if points.count > 1, let shortest = points.min(by: { $0.asleepMinutes < $1.asleepMinutes }),
           let longest = points.max(by: { $0.asleepMinutes < $1.asleepMinutes }) {
            text += ", " + extreme(shortest, isShortest: true, bucket: bucket, calendar: calendar)
            text += ", " + extreme(longest, isShortest: false, bucket: bucket, calendar: calendar)
        }
        return text + "."
    }

    private static func extreme(_ point: SleepPoint, isShortest: Bool, bucket: StatsBucket, calendar: Calendar) -> String {
        let duration = durationSpoken(minutes: point.asleepMinutes)
        let date = PulseSpoken.date(point.date, calendar: calendar)
        switch (bucket, isShortest) {
        case (.day, true): return String(localized: "nuit la plus courte \(duration) le \(date)", bundle: .module)
        case (.day, false): return String(localized: "nuit la plus longue \(duration) le \(date)", bundle: .module)
        case (.week, true): return String(localized: "semaine la plus courte \(duration) la semaine du \(date)", bundle: .module)
        case (.week, false): return String(localized: "semaine la plus longue \(duration) la semaine du \(date)", bundle: .module)
        }
    }

    /// « 7 heures 12 minutes » : des minutes dites en durée (sommeil, durée totale).
    static func durationSpoken(minutes: Double) -> String {
        guard minutes.isFinite, minutes >= 0, minutes < 1e9 else { return dash }
        return PulseSpoken.duration(seconds: Int(minutes.rounded()) * 60)
    }

    /// « Journées par état de forme, 30 jours : Forme optimale 6 jours, Forme normale 18 jours, … »
    static func categoriesSummary(_ categories: [CategoryCount], period: StatsPeriod) -> String {
        let counts = categories.map { "\($0.category.localizedName) \(daysSpoken($0.days))" }.joined(separator: ", ")
        let title = period.title
        return String(localized: "Journées par état de forme, \(title) : \(counts).", bundle: .module)
    }

    /// « 64,3 kilomètres », « 1 kilomètre » : une distance dite en toutes lettres.
    static func kilometersSpoken(meters: Double) -> String {
        guard meters.isFinite, meters >= 0 else { return dash }
        return PulseSpoken.kilometres(meters / 1000)
    }

    /// « 1 jour », « 6 jours ».
    static func daysSpoken(_ days: Int) -> String {
        PulseSpoken.count(days, singular: String(localized: "jour", bundle: .module), plural: String(localized: "jours", bundle: .module))
    }

    /// « Muscles travaillés, 30 jours : pectoraux 14 séries, quadriceps 12 séries, grands dorsaux 11,5 séries. »
    static func mapSummary(top: [MuscleLoad], period: StatsPeriod) -> String {
        let names = top.prefix(3)
            .map { "\(inlineName($0.muscle)) \(setsText($0.sets))" }
            .joined(separator: ", ")
        let title = period.title
        return String(localized: "Muscles travaillés, \(title) : \(names).", bundle: .module)
    }

    // MARK: Muscles

    /// « 14 séries », « 1 série », « 0,5 série » : des séries pondérées, une décimale au plus.
    static func setsText(_ sets: Double) -> String {
        let rounded = (sets * 10).rounded() / 10
        let number = PulseFormat.decimal(rounded, maxFractionDigits: 1)
        return rounded < 2
            ? String(localized: "\(number) série", bundle: .module)
            : String(localized: "\(number) séries", bundle: .module)
    }

    /// « abdominaux », « deltoïdes latéraux » : le nom du muscle au milieu d'une phrase.
    static func inlineName(_ muscle: Muscle) -> String {
        let name = muscle.localizedName
        return name.prefix(1).lowercased() + name.dropFirst()
    }

    // MARK: Équilibre

    /// « ratio 2 », « ratio 0,66 », ou la face manquante (« aucune série de poussée »). Deux décimales près d'une borne de
    /// `balanceRange`, arrondies vers l'extérieur hors des bornes (2 / 3 donne « 0,66 », pas « 0,67 ») : l'arrondi ne contredit
    /// jamais le signal.
    static func balanceRatioText(first: Int, second: Int, firstMissing: String, secondMissing: String) -> String {
        guard second > 0 else { return secondMissing }
        guard first > 0 else { return firstMissing }
        let ratio = Double(first) / Double(second)
        let range = MuscleStats.balanceRange
        let shown: String
        if abs(ratio - range.lowerBound) <= 0.05 || abs(ratio - range.upperBound) <= 0.05 {
            let value = ratio < range.lowerBound ? (ratio * 100).rounded(.down) / 100
                : ratio > range.upperBound ? (ratio * 100).rounded(.up) / 100 : ratio
            shown = PulseFormat.decimal(value, maxFractionDigits: 2)
        } else {
            shown = PulseFormat.decimal(ratio, maxFractionDigits: 1)
        }
        return String(localized: "ratio \(shown)", bundle: .module)
    }

    /// « Pousser et tirer : 18 séries contre 9, ratio 2, déséquilibré. »
    static func balanceSpoken(title: String, first: Int, second: Int, isUnbalanced: Bool, emptyReason: String,
                              firstMissing: String = "", secondMissing: String = "") -> String {
        guard first > 0 || second > 0 else {
            return String(localized: "\(title) : \(StatsEmptyNote.title), \(emptyReason).", bundle: .module)
        }
        let ratio = balanceRatioText(first: first, second: second, firstMissing: firstMissing, secondMissing: secondMissing)
        let verdict = isUnbalanced
            ? String(localized: "déséquilibré", bundle: .module)
            : String(localized: "équilibré", bundle: .module)
        return String(localized: "\(title) : \(first) séries contre \(second), \(ratio), \(verdict).", bundle: .module)
    }

    // MARK: Valeur de chaque marque

    /// « 12 novembre » et « 1,12 » : un point de la courbe du ratio.
    static func ratioPointSpoken(_ point: StatsPoint, calendar: Calendar) -> (label: String, value: String) {
        (PulseSpoken.date(point.date, calendar: calendar), PulseFormat.decimal(point.value, maxFractionDigits: 2))
    }

    /// « 3 novembre, Course » et « 2 650 » ; par semaine, « Semaine du 3 novembre, Vélo ».
    static func loadBarSpoken(start: Date, discipline: String, value: Double, bucket: StatsBucket,
                              calendar: Calendar) -> (label: String, value: String) {
        let when = bucketLabel(start, bucket: bucket, calendar: calendar)
        return (String(localized: "\(when), \(discipline)", bundle: .module), number(value))
    }

    /// « Nuit du 12 novembre » et « 56 millisecondes, ligne de base 54 millisecondes ».
    static func baselinePointSpoken(measure: BiometricMeasure, point: BaselinePoint, bucket: StatsBucket,
                                    calendar: Calendar) -> (label: String, value: String) {
        var value = measure.spoken(point.value)
        if let baseline = point.baseline {
            value += String(localized: ", ligne de base \(measure.spoken(baseline))", bundle: .module)
        }
        return (nightLabel(point.date, bucket: bucket, calendar: calendar), value)
    }

    /// « Nuit du 12 novembre » et « 7 heures 12 minutes, dont 1 heure 20 minutes de sommeil profond ».
    static func sleepPointSpoken(point: SleepPoint, bucket: StatsBucket, calendar: Calendar) -> (label: String, value: String) {
        var value = durationSpoken(minutes: point.asleepMinutes)
        if point.hasStages {
            let parts = [(point.deepMinutes, String(localized: "de profond", bundle: .module)),
                         (point.coreMinutes, String(localized: "de léger", bundle: .module)),
                         (point.remMinutes, String(localized: "de paradoxal", bundle: .module)),
                         (point.unspecifiedMinutes, String(localized: "sans phase", bundle: .module))]
                .compactMap { minutes, name -> String? in
                    guard let minutes, minutes.rounded() > 0 else { return nil }
                    return "\(durationSpoken(minutes: minutes)) \(name)"
                }
            if !parts.isEmpty {
                value += String(localized: ", dont \(parts.joined(separator: ", "))", bundle: .module)
            }
            return (nightLabel(point.date, bucket: bucket, calendar: calendar), value)
        }
        if let deep = point.deepMinutes, deep > 0 {
            let duration = durationSpoken(minutes: min(deep, point.asleepMinutes))
            value += String(localized: ", dont \(duration) de sommeil profond", bundle: .module)
        }
        return (nightLabel(point.date, bucket: bucket, calendar: calendar), value)
    }

    /// « Surmenage » et « 1 jour ».
    static func categorySpoken(_ count: CategoryCount) -> (label: String, value: String) {
        (count.category.localizedName, daysSpoken(count.days))
    }
}
