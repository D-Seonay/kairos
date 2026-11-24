import AVFoundation
import Foundation
import PulseDomain

/// Les annonces vocales de la course (spec V2a) : une voix française, par-dessus la musique baissée ou un podcast mis en pause.
/// `announce` rend la main dès que la phrase est en file : la course n'attend pas la fin de la voix. La session audio est rendue
/// aux autres apps quand la file est vide.
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

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "fr-FR")
    /// Les annonces en file ou en cours : la session audio n'est rendue qu'à zéro. `isSpeaking` ne suffit pas, il peut encore
    /// valoir vrai quand le délégué annonce la fin de la dernière phrase.
    private var pending = 0

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
        synthesizer.speak(utterance)
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
