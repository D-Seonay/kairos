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

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "fr-FR")

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
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseAudioIfIdle() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseAudioIfIdle() }
    }

    /// Une annonce encore en file garde la session : la musique ne remonte qu'après la dernière.
    private func releaseAudioIfIdle() {
        guard !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
