import AVFoundation
import Foundation
import PulseDomain

/// Les annonces vocales de la course (spec V2a) : une voix française, par-dessus la musique baissée ou un podcast mis en pause.
/// `announce` rend la main dès que la phrase est en file : la course n'attend pas la fin de la voix. La session audio est rendue
/// aux autres apps quand la file est vide, ou au plus tard par le filet de sécurité si iOS perd un rappel de fin.
final class SpeechRunAnnouncer: RunAnnouncing {
    func announce(_ text: String) async {
        await RunSpeaker.shared.speak(text)
    }
}

/// Le synthétiseur, gardé pour toute la vie de l'app et utilisé sur le fil principal.
@MainActor
private final class RunSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = RunSpeaker()
    /// Attente avant de retenter de rendre la session audio, si le système l'a refusé.
    private static let releaseRetryDelay = Duration.milliseconds(300)
    /// Cadence du filet de sécurité qui surveille les annonces en attente.
    private static let watchdogInterval = Duration.seconds(5)
    /// Au-delà, une annonce n'est plus attendue : une phrase de course se dit en quelques secondes.
    private static let maximumSpeechDuration = Duration.seconds(30)

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "fr-FR")
    /// Les annonces en file ou en cours : la session audio n'est rendue qu'à zéro. `isSpeaking` ne suffit pas, il peut encore
    /// valoir vrai quand le délégué annonce la fin de la dernière phrase.
    private var pending = 0
    /// Le filet de sécurité, actif tant que des annonces sont attendues : iOS peut perdre le rappel de fin d'une phrase, et la
    /// musique resterait baissée.
    private var watchdog: Task<Void, Never>?
    /// L'heure de la dernière annonce mise en file.
    private var lastSpokenAt = ContinuousClock.now

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        // Un refus de la session audio laisse la voix se débrouiller avec celle en place.
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        pending += 1
        lastSpokenAt = .now
        synthesizer.speak(utterance)
        watchPending()
    }

    /// Toutes les 5 s tant que des annonces sont attendues : un synthétiseur qui ne parle plus depuis la dernière annonce, ou une
    /// annonce attendue depuis plus de 30 s, remet le compteur à zéro et rend la session audio, même sans rappel de fin.
    private func watchPending() {
        guard watchdog == nil else { return }
        watchdog = Task { @MainActor in
            while pending > 0 {
                try? await Task.sleep(for: Self.watchdogInterval)
                guard pending > 0 else { break }
                // Une annonce mise en file à l'instant laisse au synthétiseur le temps de commencer.
                let elapsed = ContinuousClock.now - lastSpokenAt
                let isStuck = elapsed > Self.maximumSpeechDuration
                guard (!synthesizer.isSpeaking && elapsed >= Self.watchdogInterval) || isStuck else { continue }
                if isStuck { synthesizer.stopSpeaking(at: .immediate) }
                pending = 0
                releaseAudioIfIdle(retrying: true)
            }
            watchdog = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceEnded() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceEnded() }
    }

    private func utteranceEnded() {
        pending = max(0, pending - 1)
        releaseAudioIfIdle(retrying: true)
    }

    /// Une annonce encore en file garde la session : la musique ne remonte qu'après la dernière. Un refus du système (session
    /// encore occupée) est retenté une fois, un peu plus tard, si aucune annonce n'est arrivée entre-temps.
    private func releaseAudioIfIdle(retrying: Bool) {
        guard pending == 0 else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            guard retrying else { return }
            Task { @MainActor in
                try? await Task.sleep(for: Self.releaseRetryDelay)
                self.releaseAudioIfIdle(retrying: false)
            }
        }
    }
}
