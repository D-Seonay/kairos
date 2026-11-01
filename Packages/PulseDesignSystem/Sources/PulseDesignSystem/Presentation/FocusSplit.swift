/// Le libellé du curseur force / endurance de la maquette : « 60 / 40 ».
public enum FocusSplit {
    /// `focus` : 0 = tout force, 1 = tout endurance. Les deux parts sont arrondies et font toujours 100.
    public static func label(focus: Double) -> String {
        let endurance = Int((min(max(focus, 0), 1) * 100).rounded())
        return "\(100 - endurance) / \(endurance)"
    }
}
