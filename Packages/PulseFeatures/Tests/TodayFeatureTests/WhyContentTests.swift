import PulseDomain
import PulseRecoveryEngine
import Testing
@testable import TodayFeature

/// La lecture de la nuit, les trois signaux, la formule et la règle de l'écran « Pourquoi ».
struct WhyContentTests {
    // MARK: - Lecture

    @Test func readingWithThreeFactorsFollowsTheMockup() throws {
        let content = try WhyFixture.content(WhyFixture.recovery())
        #expect(content.reading == "Ta variabilité cardiaque est 18 % sous ta moyenne de 14 jours, ta fréquence au repos a pris 5 bpm "
            + "et tu n'as dormi que 5 h 10. Ton système nerveux est sous tension : la séance est allégée.")
    }

    @Test func goodNightReading() throws {
        let night = WhyFixture.recovery(score: 95) {
            $0.sdnnMs = 56
            $0.sdnnBaselineMs = 50
            $0.restingHeartRate = 48
            $0.restingHeartRateBaseline = 50
            $0.asleepMinutes = 480
        }
        let content = try WhyFixture.content(night)
        #expect(content.reading == "Ta variabilité cardiaque est 12 % au-dessus de ta moyenne de 14 jours, "
            + "ta fréquence au repos a baissé de 2 bpm et tu as dormi 8 h. Tu es en pleine forme : la séance prévue reste telle quelle.")
    }

    @Test func nearBaselineReadings() throws {
        let night = WhyFixture.recovery(score: 80) {
            $0.sdnnMs = 52
            $0.sdnnBaselineMs = 50
            $0.restingHeartRate = 50
            $0.restingHeartRateBaseline = 49
            $0.asleepMinutes = 420
        }
        let content = try WhyFixture.content(night)
        #expect(content.reading.hasPrefix("Ta variabilité cardiaque est proche de ta moyenne de 14 jours, "
            + "ta fréquence au repos est stable et tu as dormi 7 h. "))
    }

    /// L'écart est arrondi avant d'être comparé : −5 % est « sous », −4 % est « proche », +2 bpm est « pris ».
    @Test(arguments: [
        (47.5, "ta variabilité cardiaque est 5 % sous ta moyenne de 14 jours"),
        (47.9, "ta variabilité cardiaque est proche de ta moyenne de 14 jours"),
        (52.5, "ta variabilité cardiaque est 5 % au-dessus de ta moyenne de 14 jours"),
        (52.2, "ta variabilité cardiaque est proche de ta moyenne de 14 jours")
    ])
    func hrvThresholds(sdnn: Double, clause: String) throws {
        let night = WhyFixture.recovery {
            $0.sdnnMs = sdnn
            $0.sdnnBaselineMs = 50
        }
        let content = try WhyFixture.content(night)
        #expect(content.reading.lowercased().hasPrefix(clause))
    }

    @Test(arguments: [
        (2.0, "ta fréquence au repos a pris 2 bpm"),
        (1.0, "ta fréquence au repos est stable"),
        (0.0, "ta fréquence au repos est stable"),
        (-1.0, "ta fréquence au repos est stable"),
        (-2.0, "ta fréquence au repos a baissé de 2 bpm")
    ])
    func restingHeartRateThresholds(change: Double, clause: String) throws {
        let night = WhyFixture.recovery {
            $0.restingHeartRate = 50 + change
            $0.restingHeartRateBaseline = 50
        }
        let content = try WhyFixture.content(night)
        #expect(content.reading.contains(clause))
    }

    @Test func missingHRVIsSaid() throws {
        let night = WhyFixture.recovery {
            $0.hrvScore = nil
            $0.sdnnMs = nil
            $0.sdnnBaselineMs = nil
            $0.missingFactors = [.hrv]
        }
        let content = try WhyFixture.content(night)
        #expect(content.reading.contains("Pas de variabilité cette nuit : le score repose sur le sommeil et la fréquence au repos."))
        #expect(content.reading.hasPrefix("Ta fréquence au repos a pris 5 bpm et tu n'as dormi que 5 h 10. "))
    }

    @Test func missingRestingHeartRateIsSaid() throws {
        let night = WhyFixture.recovery {
            $0.restingHeartRateScore = nil
            $0.restingHeartRate = nil
            $0.restingHeartRateBaseline = nil
            $0.missingFactors = [.restingHeartRate]
        }
        let content = try WhyFixture.content(night)
        #expect(content.reading.contains("Pas de fréquence au repos cette nuit : le score repose sur la variabilité et le sommeil."))
    }

    @Test func missingSleepIsSaid() throws {
        let night = WhyFixture.recovery {
            $0.sleepScore = nil
            $0.asleepMinutes = nil
            $0.missingFactors = [.sleep]
        }
        let content = try WhyFixture.content(night)
        #expect(content.reading.contains(
            "Pas de sommeil enregistré cette nuit : le score repose sur la variabilité et la fréquence au repos."))
    }

    @Test func calibrationIsSaid() throws {
        let content = try WhyFixture.content(WhyFixture.recovery { $0.calibration = .calibrating(nights: 9) })
        #expect(content.reading.contains("Ta ligne de base se construit encore : 9 nuits sur 14. Ton système nerveux"))
    }

    @Test func calibrationIsSilentWithoutHRV() throws {
        let night = WhyFixture.recovery {
            $0.hrvScore = nil
            $0.sdnnMs = nil
            $0.missingFactors = [.hrv]
            $0.calibration = .calibrating(nights: 3)
        }
        let content = try WhyFixture.content(night)
        #expect(!content.reading.contains("ligne de base"))
    }

    @Test(arguments: [
        (95.0, "Tu es en pleine forme : la séance prévue reste telle quelle."),
        (75.0, "Ta récupération est correcte : la séance reste la même, avec un peu plus de repos."),
        (58.0, "Ton système nerveux est sous tension : la séance est allégée."),
        (30.0, "Ton corps demande du repos : mobilité douce ou repos complet aujourd'hui.")
    ])
    func readingEndsOnTheCategoryConclusion(score: Double, conclusion: String) throws {
        let content = try WhyFixture.content(WhyFixture.recovery(score: score))
        #expect(content.reading.hasSuffix(" " + conclusion))
    }

    // MARK: - Signaux

    @Test func signalsFollowTheThreeFactors() throws {
        let content = try WhyFixture.content(WhyFixture.recovery())
        #expect(content.signals == [
            WhyContent.Signal(title: "Variabilité", score: 59),
            WhyContent.Signal(title: "FC au repos", score: 58),
            WhyContent.Signal(title: "Sommeil", score: 56)
        ])
    }

    @Test func subScoresAreRounded() throws {
        let night = WhyFixture.recovery { $0.hrvScore = 58.6; $0.restingHeartRateScore = 57.5; $0.sleepScore = 55.4 }
        let content = try WhyFixture.content(night)
        #expect(content.signals.map(\.score) == [59, 58, 55])
    }

    @Test func formulaUsesTheAppliedWeights() throws {
        let content = try WhyFixture.content(WhyFixture.recovery())
        #expect(content.formula == "Score = 50 % × 59 + 25 % × 58 + 25 % × 56 = 58")
    }

    @Test func formulaRenormalisesWithoutHRV() throws {
        let night = WhyFixture.recovery(score: 57) {
            $0.hrvScore = nil
            $0.restingHeartRateScore = 58
            $0.sleepScore = 56
            $0.sdnnMs = nil
            $0.missingFactors = [.hrv]
        }
        let content = try WhyFixture.content(night)
        #expect(content.formula == "Score = 50 % × 58 + 50 % × 56 = 57")
        #expect(content.signals.map(\.title) == ["FC au repos", "Sommeil"])
    }

    @Test func formulaRenormalisesWithoutSleep() throws {
        let night = WhyFixture.recovery(score: 59) {
            $0.sleepScore = nil
            $0.asleepMinutes = nil
            $0.missingFactors = [.sleep]
        }
        let content = try WhyFixture.content(night)
        #expect(content.formula == "Score = 67 % × 59 + 33 % × 58 = 59")
    }

    @Test func formulaWithoutAnyFactorIsTheBareScore() throws {
        let night = WhyFixture.recovery {
            $0.hrvScore = nil
            $0.restingHeartRateScore = nil
            $0.sleepScore = nil
        }
        let content = try WhyFixture.content(night)
        #expect(content.signals.isEmpty)
        #expect(content.formula == "Score = 58")
    }

    // MARK: - Score estimé

    @Test func estimatedShowsTheAnswers() throws {
        let checkIn = WhyFixture.checkIn(sleep: 3, pain: 3, motivation: 3, score: 75)
        let content = try WhyFixture.content(WhyFixture.estimated(score: 75), checkIn: checkIn)
        #expect(content.signals == [
            WhyContent.Signal(title: "Sommeil : Bon", score: 75),
            WhyContent.Signal(title: "Courbatures et douleurs : Légères", score: 75),
            WhyContent.Signal(title: "Motivation : Bonne", score: 75)
        ])
        #expect(content.formula == "Score = 40 % × 75 + 35 % × 75 + 25 % × 75 = 75")
        #expect(content.reading == "Pas de données de nuit : ce score vient de ton check-in. "
            + "Ta récupération est correcte : la séance reste la même, avec un peu plus de repos.")
    }

    @Test func estimatedFormulaMatchesTheScorer() throws {
        let answers = CheckInAnswers(sleep: 4, pain: 1, motivation: 0)
        let score = CheckInScorer.score(answers)
        let checkIn = WhyFixture.checkIn(sleep: 4, pain: 1, motivation: 0, score: score)
        let content = try WhyFixture.content(WhyFixture.estimated(score: score), checkIn: checkIn)
        #expect(content.signals == [
            WhyContent.Signal(title: "Sommeil : Excellent", score: 100),
            WhyContent.Signal(title: "Courbatures et douleurs : Marquées", score: 25),
            WhyContent.Signal(title: "Motivation : Zéro", score: 0)
        ])
        #expect(content.formula == "Score = 40 % × 100 + 35 % × 25 + 25 % × 0 = 49")
    }

    @Test func estimatedWithoutTheAnswersStillExplainsTheScore() throws {
        let content = try WhyFixture.content(WhyFixture.estimated(score: 75))
        #expect(content.signals.isEmpty)
        #expect(content.formula == "Score estimé à partir de ton check-in : 75")
        #expect(content.reading.hasPrefix("Pas de données de nuit : ce score vient de ton check-in. "))
    }

    // MARK: - Règle

    @Test(arguments: [
        (95.0, "À 90 et plus, la séance prévue reste telle quelle."),
        (75.0, "Entre 65 et 89, la séance reste la même, avec 15 secondes de repos en plus entre les séries."),
        (58.0, "Entre 40 et 64, la séance perd 20 % de son volume, l'effort est plafonné à RPE 7,5 "
            + "et les repos s'allongent de 45 secondes."),
        (30.0, "Sous 40, la séance laisse place à 20 minutes de mobilité ou à du repos, au choix.")
    ])
    func categoryRules(score: Double, rule: String) throws {
        let content = try WhyFixture.content(WhyFixture.recovery(score: score))
        #expect(content.rule == rule)
    }
}
