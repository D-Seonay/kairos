/// Les identifiants d'accessibilité des éléments que les tests d'interface lisent.
public enum LiveSessionIdentifiers {
    public static let resumeBanner = "live.resumeBanner"
    public static let resumeButton = "live.resume"
    public static let abandonBannerButton = "live.abandonBanner"
    public static let finishButton = "live.finish"
    public static let menuButton = "live.menu"
    public static let abandonButton = "live.abandon"
    public static let keypad = "live.keypad"
    public static let keypadKeyPrefix = "live.key."
    public static let rpePrefix = "live.rpe."
    public static let restBar = "live.rest"
    public static let restMinus30 = "live.rest.minus30"
    public static let restPlus30 = "live.rest.plus30"
    public static let restSkip = "live.rest.skip"
    public static let addSet = "live.addSet"
    public static let addExercise = "live.addExercise"

    /// « live.exercise.0.set.1.check » : la coche de la deuxième série du premier exercice.
    public static func check(exercise: Int, set: Int) -> String { setField(exercise, set, "check") }
    public static func weight(exercise: Int, set: Int) -> String { setField(exercise, set, "weight") }
    public static func reps(exercise: Int, set: Int) -> String { setField(exercise, set, "reps") }
    public static func rpe(exercise: Int, set: Int) -> String { setField(exercise, set, "rpe") }

    private static func setField(_ exercise: Int, _ set: Int, _ field: String) -> String {
        "live.exercise.\(exercise).set.\(set).\(field)"
    }
}
