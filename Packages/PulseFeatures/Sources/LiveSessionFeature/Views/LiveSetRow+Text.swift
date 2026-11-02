import PulseDesignSystem
import PulseDomain
import PulseServices

/// Les textes d'une ligne de série, en fonctions pures pour les tester : colonne de charge, pastille du type, étiquette VoiceOver.
extension LiveSetRow {
    /// Le titre de la colonne de charge : « kg », « +kg » (lest du poids du corps) ou « −kg » (assistance).
    nonisolated static func weightColumnTitle(for loadKind: LoadKind) -> String {
        switch loadKind {
        case .external: String(localized: "kg", bundle: .module)
        case .bodyweight: String(localized: "+kg", bundle: .module)
        case .assisted: String(localized: "\u{2212}kg", bundle: .module)
        }
    }

    /// La charge de la colonne : « 62,5 ». Sans valeur, un tiret pour une charge externe et « 0 » pour le lest ou l'assistance.
    nonisolated static func weightText(_ weightKg: Double?, loadKind: LoadKind) -> String {
        if let weightKg { return PulseFormat.decimal(weightKg, maxFractionDigits: 2) }
        return loadKind == .external ? "\u{2013}" : "0"
    }

    /// La pastille du numéro : la position pour une série normale, « É », « D » ou « X » sinon.
    nonisolated static func badge(for type: SetType, index: Int) -> String {
        switch type {
        case .working: "\(index + 1)"
        case .warmup: "É"
        case .drop: "D"
        case .failure: "X"
        }
    }

    /// Vrai tant que la valeur est celle que Pulse a proposée (couleur d'accent) : une série modifiée ne perd l'accent que sur
    /// la valeur qu'elle a changée.
    nonisolated static func isProposed(_ kind: KeypadField.Kind, in set: LiveSet) -> Bool {
        guard set.isEdited else { return true }
        return switch kind {
        case .weight: set.weightKg == set.proposed.weightKg
        case .reps: set.reps == set.proposed.reps
        case .duration: set.durationSeconds == set.proposed.durationSeconds
        }
    }

    // MARK: VoiceOver

    /// « Série 2, proposé 70 kilos, 5 répétitions, non validée ». `index` est la position de la série dans l'exercice, à partir
    /// de 0. « proposé » précède la première valeur tant que la série n'a ni été modifiée ni validée.
    nonisolated static func accessibilityText(for set: LiveSet, index: Int, loadKind: LoadKind, tracksDuration: Bool = false) -> String {
        var parts = [String(localized: "Série \(index + 1)", bundle: .module)]
        if let type = typeName(set.setType) { parts.append(type) }
        var values = spokenValues(of: set, loadKind: loadKind, tracksDuration: tracksDuration)
        if !set.isEdited, set.completedAt == nil, let first = values.firstIndex(where: { !$0.isMissing }) {
            values[first].text = String(localized: "proposé \(values[first].text)", bundle: .module)
        }
        parts += values.map(\.text)
        if let rpe = set.rpe {
            parts.append(String(localized: "RPE \(PulseFormat.decimal(rpe, maxFractionDigits: 1))", bundle: .module))
        }
        parts.append(set.completedAt == nil ? String(localized: "non validée", bundle: .module)
                        : String(localized: "validée", bundle: .module))
        return parts.joined(separator: ", ")
    }

    /// Le nom parlé d'un type de série ; `nil` pour une série normale.
    nonisolated static func typeName(_ type: SetType) -> String? {
        switch type {
        case .working: nil
        case .warmup: String(localized: "échauffement", bundle: .module)
        case .drop: String(localized: "dégressive", bundle: .module)
        case .failure: String(localized: "à l'échec", bundle: .module)
        }
    }

    private struct SpokenValue {
        var text: String
        var isMissing = false
    }

    private nonisolated static func spokenValues(of set: LiveSet, loadKind: LoadKind, tracksDuration: Bool) -> [SpokenValue] {
        var values: [SpokenValue] = []
        let weightKg = set.weightKg ?? 0
        switch loadKind {
        case .external:
            if let weight = set.weightKg {
                values.append(SpokenValue(text: kilos(weight)))
            } else {
                values.append(SpokenValue(text: String(localized: "charge à saisir", bundle: .module), isMissing: true))
            }
        case .bodyweight where weightKg > 0:
            values.append(SpokenValue(text: String(localized: "lest de \(kilos(weightKg))", bundle: .module)))
        case .assisted where weightKg > 0:
            values.append(SpokenValue(text: String(localized: "assistance de \(kilos(weightKg))", bundle: .module)))
        case .bodyweight, .assisted:
            break
        }
        if tracksDuration {
            values.append(set.durationSeconds.map { SpokenValue(text: seconds($0)) }
                ?? SpokenValue(text: String(localized: "durée à saisir", bundle: .module), isMissing: true))
        } else {
            values.append(set.reps.map { SpokenValue(text: repetitions($0)) }
                ?? SpokenValue(text: String(localized: "répétitions à saisir", bundle: .module), isMissing: true))
        }
        return values
    }

    /// « 1 kilo », « 1,5 kilo » : le pluriel commence à 2.
    private nonisolated static func kilos(_ value: Double) -> String {
        let text = PulseFormat.decimal(value, maxFractionDigits: 2)
        return abs(value) < 2 ? String(localized: "\(text) kilo", bundle: .module)
            : String(localized: "\(text) kilos", bundle: .module)
    }

    private nonisolated static func repetitions(_ count: Int) -> String {
        count == 1 ? String(localized: "1 répétition", bundle: .module)
            : String(localized: "\(count) répétitions", bundle: .module)
    }

    private nonisolated static func seconds(_ count: Int) -> String {
        count == 1 ? String(localized: "1 seconde", bundle: .module)
            : String(localized: "\(count) secondes", bundle: .module)
    }
}
