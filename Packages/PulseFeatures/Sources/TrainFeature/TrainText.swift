import Foundation
import PulseContent
import PulseDesignSystem
import PulseDomain

/// Les textes de l'onglet Séance qui se disent et se comptent : les pluriels (affichés et lus), les séries dites en mots, les
/// résumés de routine et d'exercice de routine. Des fonctions pures, pour les tester ; rien n'est composé dans une vue.
/// Le texte visible garde ses signes (« × », « · », « ~ ») ; sa variante dite n'en contient aucun.
enum TrainText {
    // MARK: - Pluriels

    /// « 0 exercice », « 1 exercice », « 5 exercices » : le singulier jusqu'à 1.
    static func exercises(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "exercice", bundle: .module),
                          plural: String(localized: "exercices", bundle: .module))
    }

    /// « 1 série », « 12 séries ».
    static func sets(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "série", bundle: .module),
                          plural: String(localized: "séries", bundle: .module))
    }

    /// « 1 séance », « 42 séances ».
    static func sessions(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "séance", bundle: .module),
                          plural: String(localized: "séances", bundle: .module))
    }

    /// « 1 routine », « 4 routines ».
    static func routines(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "routine", bundle: .module),
                          plural: String(localized: "routines", bundle: .module))
    }

    /// « 1 record », « 2 records ».
    static func records(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "record", bundle: .module),
                          plural: String(localized: "records", bundle: .module))
    }

    /// « 1 répétition », « 8 répétitions ».
    static func repetitions(_ count: Int) -> String {
        PulseSpoken.count(count, singular: String(localized: "répétition", bundle: .module),
                          plural: String(localized: "répétitions", bundle: .module))
    }

    /// « 1 kilomètre », « 1,5 kilomètre », « 10 kilomètres » : le pluriel commence à 2.
    static func kilometres(_ kilometres: Double) -> String {
        let number = PulseFormat.grouped(kilometres, maxFractionDigits: 1)
        return abs(kilometres) < 2
            ? String(localized: "\(number) kilomètre", bundle: .module)
            : String(localized: "\(number) kilomètres", bundle: .module)
    }

    /// « 1 séance importée », « 42 séances importées » : le participe s'accorde, le singulier va jusqu'à 1.
    static func importedSessions(_ count: Int) -> String {
        let number = PulseFormat.grouped(Double(count), maxFractionDigits: 0)
        return count <= 1 ? String(localized: "\(number) séance importée", bundle: .module)
            : String(localized: "\(number) séances importées", bundle: .module)
    }

    /// « Importer 1 séance », « Importer 42 séances ».
    static func importTitle(sessions count: Int) -> String {
        String(localized: "Importer \(sessions(count))", bundle: .module)
    }

    /// « 12 450 kilos » : un tonnage arrondi au kilo, dit en toutes lettres.
    static func tonnage(_ kilograms: Double) -> String {
        PulseSpoken.kilos(kilograms.rounded())
    }

    // MARK: - Séries dites en mots

    /// « 70 kilos, 5 répétitions », « lest de 10 kilos, 8 répétitions », « assistance de 15 kilos, 8 répétitions »,
    /// « 45 secondes », « non renseignée » sans rien de saisi. Les répétitions l'emportent sur la durée, comme à l'écran.
    static func spokenSet(of set: WorkoutSet, loadKind: LoadKind) -> String {
        spokenSet(weightKg: set.actualWeightKg ?? 0, reps: set.actualReps, durationSeconds: set.durationSeconds, loadKind: loadKind)
    }

    static func spokenSet(weightKg: Double, reps: Int?, durationSeconds: Int?, loadKind: LoadKind) -> String {
        guard let value = value(reps: reps, durationSeconds: durationSeconds) else {
            return String(localized: "non renseignée", bundle: .module)
        }
        guard let load = load(weightKg, loadKind: loadKind) else { return value.text }
        return String(localized: "\(load), \(value.text)", bundle: .module)
    }

    /// La meilleure série : « 72,5 kilos, 5 répétitions », « assistance de 15 kilos, 8 répétitions », « 12 répétitions ».
    static func spokenBestSet(_ set: BestSet) -> String {
        let loadKind: LoadKind = set.isAssisted ? .assisted : (set.isBodyweight ? .bodyweight : .external)
        return spokenSet(weightKg: set.weightKg, reps: set.reps, durationSeconds: nil, loadKind: loadKind)
    }

    /// Les séries d'une séance regroupées par charge : « 70 kilos, 2 séries de 5 répétitions », « 60 kilos, 8 répétitions, puis
    /// 70 kilos, 5 répétitions puis 4 répétitions », « 2 séries de 45 secondes ». Une série qui répète la précédente se compte.
    static func spokenSets(_ sets: [WorkoutSet], loadKind: LoadKind) -> String {
        var groups: [(weight: Double, values: [Value])] = []
        for set in sets {
            guard let value = value(reps: set.actualReps, durationSeconds: set.durationSeconds) else { continue }
            let weight = set.actualWeightKg ?? 0
            if let last = groups.last, last.weight == weight {
                groups[groups.count - 1].values.append(value)
            } else {
                groups.append((weight, [value]))
            }
        }
        guard !groups.isEmpty else { return String(localized: "non renseignée", bundle: .module) }
        let texts = groups.map { group -> String in
            let values = runs(of: group.values).joined(separator: String(localized: " puis ", bundle: .module))
            guard let load = load(group.weight, loadKind: loadKind) else { return values }
            return String(localized: "\(load), \(values)", bundle: .module)
        }
        return texts.joined(separator: String(localized: ", puis ", bundle: .module))
    }

    /// Une série du détail d'une séance : « 80 kilos, 5 répétitions, échauffement, RPE 8, record ».
    static func sessionSetSpoken(_ line: SessionSetLine) -> String {
        var parts = [line.spokenText]
        switch line.type {
        case .working: break
        case .warmup: parts.append(String(localized: "échauffement", bundle: .module))
        case .drop: parts.append(String(localized: "dégressive", bundle: .module))
        case .failure: parts.append(String(localized: "à l'échec", bundle: .module))
        }
        if let rpe = line.rpe { parts.append(String(localized: "RPE \(PulseFormat.decimal(rpe, maxFractionDigits: 1))", bundle: .module)) }
        if line.isRecord { parts.append(String(localized: "record", bundle: .module)) }
        return parts.joined(separator: ", ")
    }

    /// Une carte de chiffre clé dite d'un trait : « Maximum estimé sur une répétition, 80 kilos, en hausse de 2,5 kilos en 30 jours ».
    static func indicatorSpoken(title: String, value: String, detail: String?) -> String {
        [title, value, detail].compactMap(\.self).joined(separator: ", ")
    }

    /// Une séance d'un exercice : « 26 octobre, 70 kilos, 2 séries de 5 répétitions, RPE 8, 700 kilos au total, record ».
    static func spokenHistoryLine(_ line: ExerciseHistoryLine, dateText: String) -> String {
        var parts = [dateText, line.spokenSetsText]
        if let rpe = line.maxRPE {
            parts.append(String(localized: "RPE \(PulseFormat.decimal(rpe, maxFractionDigits: 1))", bundle: .module))
        }
        parts.append(String(localized: "\(tonnage(line.tonnageKg)) au total", bundle: .module))
        if line.hasRecord { parts.append(String(localized: "record", bundle: .module)) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Bibliothèque

    /// « Pectoraux · barre · 1RM 65 kg » : le groupe, le matériel en minuscules et le meilleur 1RM s'il y en a un.
    static func exerciseRowSubtitle(group: String, equipment: String, oneRepMax: Double?) -> String {
        var parts = [group, equipment.lowercased()]
        if let oneRepMax {
            parts.append(String(localized: "1RM \(PulseFormat.decimal(oneRepMax, maxFractionDigits: 1)) kg", bundle: .module))
        }
        return parts.joined(separator: " · ")
    }

    /// « Pectoraux, barre, maximum estimé 65 kilos » : la même ligne dite en mots.
    static func exerciseRowSubtitleSpoken(group: String, equipment: String, oneRepMax: Double?) -> String {
        var parts = [group, equipment.lowercased()]
        if let oneRepMax {
            parts.append(String(localized: "maximum estimé \(PulseSpoken.kilos((oneRepMax * 10).rounded() / 10))", bundle: .module))
        }
        return parts.joined(separator: ", ")
    }

    /// « Ajouter » sans choix, « Ajouter (3) » avec trois exercices choisis.
    static func addSelectionTitle(count: Int) -> String {
        count == 0 ? String(localized: "Ajouter", bundle: .module) : String(localized: "Ajouter (\(count))", bundle: .module)
    }

    /// « Ajouter », « Ajouter 1 exercice », « Ajouter 3 exercices ».
    static func addSelectionSpoken(count: Int) -> String {
        count == 0 ? String(localized: "Ajouter", bundle: .module) : String(localized: "Ajouter \(exercises(count))", bundle: .module)
    }

    // MARK: - Historique

    /// « 12 séries · 4 250 kg » : les séries de travail et le tonnage d'une séance de l'historique.
    static func historyVolume(_ line: HistoryLine) -> String {
        "\(sets(line.workingSets)) · \(HistoryRow.tonnage(line.tonnageKg))"
    }

    /// « Push, importée de Hevy, abandonnée, lundi 27 octobre, 1 heure 5 minutes, 12 séries, 4 250 kilos, 2 records » : une
    /// ligne de l'historique dite en mots. `spokenDate` est la date en toutes lettres.
    static func historyRowSpoken(_ line: HistoryLine, spokenDate: String) -> String {
        var parts = [line.title]
        if line.isImported { parts.append(String(localized: "importée de Hevy", bundle: .module)) }
        if line.isAbandoned { parts.append(String(localized: "abandonnée", bundle: .module)) }
        parts.append(spokenDate)
        if let minutes = line.durationMinutes, minutes > 0 { parts.append(PulseSpoken.duration(seconds: minutes * 60)) }
        parts.append(sets(line.workingSets))
        parts.append(tonnage(line.tonnageKg))
        if line.recordCount > 0 { parts.append(records(line.recordCount)) }
        return parts.joined(separator: ", ")
    }

    // MARK: - Import Hevy

    /// « 12 séances · 80 séries » : ce qu'un nom de Hevy contient.
    static func mappingCounts(sessions sessionCount: Int, sets setCount: Int) -> String {
        String(localized: "\(sessions(sessionCount)) · \(sets(setCount))", bundle: .module)
    }

    /// « Développé couché, 12 séances, 80 séries. Choix : Développé couché, à vérifier ».
    static func mappingRowSpoken(name: String, sessions sessionCount: Int, sets setCount: Int, choice: String,
                                 needsReview: Bool) -> String {
        let counts = [sessions(sessionCount), sets(setCount)].joined(separator: ", ")
        let review = needsReview ? String(localized: ", à vérifier", bundle: .module) : ""
        return String(localized: "\(name), \(counts). Choix : \(choice)\(review)", bundle: .module)
    }

    // MARK: - Résumé d'import

    /// « du 3 septembre 2026 au 26 octobre 2026 » : la période dite sans abréviation de mois.
    static func spokenPeriod(from first: String, to last: String) -> String {
        first == last ? first : String(localized: "du \(first) au \(last)", bundle: .module)
    }

    // MARK: - Interne

    private struct Value: Equatable {
        var text: String
    }

    private static func value(reps: Int?, durationSeconds: Int?) -> Value? {
        if let reps, reps > 0 { return Value(text: repetitions(reps)) }
        if let durationSeconds, durationSeconds > 0 { return Value(text: PulseSpoken.duration(seconds: durationSeconds)) }
        return nil
    }

    /// La charge dite : « 70 kilos », « lest de 10 kilos », « assistance de 15 kilos » ; `nil` sans charge.
    private static func load(_ weightKg: Double, loadKind: LoadKind) -> String? {
        guard weightKg > 0 else { return nil }
        switch loadKind {
        case .external: return PulseSpoken.kilos(weightKg)
        case .bodyweight: return String(localized: "lest de \(PulseSpoken.kilos(weightKg))", bundle: .module)
        case .assisted: return String(localized: "assistance de \(PulseSpoken.kilos(weightKg))", bundle: .module)
        }
    }

    /// Les valeurs qui se répètent d'affilée se comptent : [5, 5, 4] donne « 2 séries de 5 répétitions », « 4 répétitions ».
    private static func runs(of values: [Value]) -> [String] {
        var runs: [(value: Value, count: Int)] = []
        for value in values {
            if let last = runs.last, last.value == value {
                runs[runs.count - 1].count += 1
            } else {
                runs.append((value, 1))
            }
        }
        return runs.map { run in
            run.count == 1 ? run.value.text : String(localized: "\(sets(run.count)) de \(run.value.text)", bundle: .module)
        }
    }

}
