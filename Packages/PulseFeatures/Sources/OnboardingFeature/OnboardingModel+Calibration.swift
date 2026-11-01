import Foundation
import PulseDomain
import PulseServices

extension OnboardingModel {
    /// Lit 60 jours d'Apple Santé, calcule le premier score et la ligne de base ; sans lecture ou sans assez de données,
    /// la calibration passe par le check-in. Avant 4 h le jour n'a pas commencé : aucun score n'est calculé, le check-in est demandé.
    public func runCalibration() async {
        errorMessage = nil
        await calibrate()
    }

    /// Reprise de l'onboarding à `.calibration` : `start()` ne fait que restaurer l'étape, c'est à l'écran de relancer la calibration.
    /// Sans effet hors de l'étape, ou si une calibration est déjà passée ou en cours (`calibrate()` quitte `.idle` sans attendre).
    public func resumeCalibrationIfNeeded() async {
        guard step == .calibration, calibration == .idle else { return }
        await calibrate()
    }

    /// Comme `runCalibration()`, sans effacer le message d'erreur laissé par l'étape qui précède.
    /// Une lecture qui n'est plus la dernière lancée, ou que `goBack()` a annulée, ne change rien.
    func calibrate() async {
        calibrationGeneration += 1
        let generation = calibrationGeneration
        let now = environment.now()
        guard !healthSkipped else {
            calibration = .needsCheckIn(missing: Factor.allCases, baseline: baseline(of: [], at: now))
            return
        }
        calibration = .reading(progress: 0)
        let snapshot = await environment.nightHistory.refresh(now: now) { [weak self] progress in
            Task { @MainActor in self?.updateReading(progress, generation: generation) }
        }
        guard generation == calibrationGeneration else { return }
        let baseline = baseline(of: snapshot.nights, at: now)
        var phase = CalibrationPhase.needsCheckIn(missing: Factor.allCases, baseline: baseline)
        var failure: String?
        do {
            switch try await environment.scores.update(nights: snapshot.nights, now: now) {
            case .scored(let recovery):
                phase = .scored(recovery, baseline)
            case .needsCheckIn(let missing):
                phase = .needsCheckIn(missing: missing, baseline: baseline)
            case .beforeDayStart:
                break
            }
        } catch {
            failure = String(localized: "Pulse n'a pas pu calculer ton score pour le moment.", bundle: .module)
        }
        guard generation == calibrationGeneration else { return }
        if let failure {
            errorMessage = failure
        }
        calibration = phase
    }

    /// Enregistre le check-in rempli et affiche le score estimé qu'il produit. Une seconde touche pendant l'enregistrement est ignorée.
    public func submitCheckIn() async {
        guard !isSubmittingCheckIn, let answers = checkIn.answers, case .needsCheckIn(_, let baseline) = calibration else { return }
        isSubmittingCheckIn = true
        defer { isSubmittingCheckIn = false }
        errorMessage = nil
        let generation = calibrationGeneration
        do {
            let recovery = try await environment.scores.saveCheckIn(answers, now: environment.now())
            guard generation == calibrationGeneration else { return }
            calibration = .scored(recovery, baseline)
        } catch {
            guard generation == calibrationGeneration else { return }
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer ton check-in.", bundle: .module)
        }
    }

    private func baseline(of nights: [NightSample], at now: Date) -> BaselineSummary {
        BaselineSummary.make(nights: nights, day: now, calendar: environment.calendar)
    }

    /// La progression n'est prise en compte que pendant la lecture dont elle vient : une mise à jour tardive ne doit rien écraser.
    private func updateReading(_ progress: Double, generation: Int) {
        guard generation == calibrationGeneration, case .reading = calibration else { return }
        calibration = .reading(progress: progress)
    }
}
