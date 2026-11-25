/// Les identifiants d'accessibilité des éléments que les tests d'interface lisent.
public enum SupplementsIdentifiers {
    public static let card = "supplements.card"
    public static let cardTake = "supplements.card.take"
    public static let add = "supplements.add"
    public static let formName = "supplements.form.name"
    public static let formDose = "supplements.form.dose"
    public static let formSave = "supplements.form.save"
    public static let summary = "supplements.summary"

    /// La coche d'un complément, par son nom.
    public static func check(_ name: String) -> String {
        "supplements.check.\(name)"
    }

    /// « Désarchiver » d'un complément archivé, par son nom.
    public static func unarchive(_ name: String) -> String {
        "supplements.unarchive.\(name)"
    }
}
