import Foundation
import PulseDomain
import PulseServices

extension OnboardingModel {
    /// Lit 60 jours d'Apple Santé, calcule le premier score et la ligne de base ; sans lecture ou sans assez de données,
    /// la calibration passe par le check-in. Avant 4 h le jour n'a pas commencé : aucun score n'est calculé, le check-in est demandé.
    ///
    /// Une reprise de l'onboarding à `.calibration` ne relance pas la calibration d'elle-même (`start()` ne fait que restaurer
    /// l'étape) : c'est à l'écran de la lancer à son apparition.
    public func runCalibration() async {
        errorMessage = nil
        await calibrate()
    }

    /// Comme `runCalibration()`, sans effacer le message d'erreur laissé par l'étape qui précède.
    func calibrate() async {
        let now = environment.now()
        guard !healthSkipped else {
            calibration = .needsCheckIn(missing: Factor.allCases, baseline: baseline(of: [], at: now))
            return
        }
        calibration = .reading(progress: 0)
        let snapshot = await environment.nightHistory.refresh(now: now) { [weak self] progress in
            Task { @MainActor in self?.updateReading(progress) }
        }
        let baseline = baseline(of: snapshot.nights, at: now)
        do {
            switch try await environment.scores.update(nights: snapshot.nights, now: now) {
            case .scored(let recovery):
                calibration = .scored(recovery, baseline)
            case .needsCheckIn(let missing):
                calibration = .needsCheckIn(missing: missing, baseline: baseline)
            case .beforeDayStart:
                calibration = .needsCheckIn(missing: Factor.allCases, baseline: baseline)
            }
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu calculer ton score pour le moment.", bundle: .module)
            calibration = .needsCheckIn(missing: Factor.allCases, baseline: baseline)
        }
    }

    /// Enregistre le check-in rempli et affiche le score estimé qu'il produit.
    public func submitCheckIn() async {
        guard let answers = checkIn.answers, case .needsCheckIn(_, let baseline) = calibration else { return }
        errorMessage = nil
        do {
            let recovery = try await environment.scores.saveCheckIn(answers, now: environment.now())
            calibration = .scored(recovery, baseline)
        } catch {
            errorMessage = String(localized: "Pulse n'a pas pu enregistrer ton check-in.", bundle: .module)
        }
    }

    private func baseline(of nights: [NightSample], at now: Date) -> BaselineSummary {
        BaselineSummary.make(nights: nights, day: now, calendar: environment.calendar)
    }

    /// La progression n'est prise en compte que pendant la lecture : une mise à jour tardive ne doit pas écraser le résultat.
    private func updateReading(_ progress: Double) {
        guard case .reading = calibration else { return }
        calibration = .reading(progress: progress)
    }
}
