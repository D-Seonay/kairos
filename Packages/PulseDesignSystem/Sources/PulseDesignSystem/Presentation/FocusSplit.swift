/// Le libellé du curseur force / endurance de la maquette : « 60 / 40 ».
public enum FocusSplit {
    /// `focus` : 0 = tout force, 1 = tout endurance. Les deux parts sont arrondies et font toujours 100.
    /// Une valeur hors de 0...1 est ramenée dans l'intervalle ; une valeur non numérique vaut l'équilibre 50 / 50.
    public static func label(focus: Double) -> String {
        let safe = focus.isNaN ? 0.5 : min(max(focus, 0), 1)
        let endurance = Int((safe * 100).rounded())
        return "\(100 - endurance) / \(endurance)"
    }
}
