import SwiftUI

/// Les annonces VoiceOver : ce qui change à l'écran sans que le focus bouge (une erreur, une fin de repos, un record).
public enum PulseAnnouncement {
    /// Annonce `text`. Une erreur coupe la parole en cours (priorité haute), le reste attend son tour.
    public static func post(_ text: String, isError: Bool = false) {
        var message = AttributedString(text)
        message.accessibilitySpeechAnnouncementPriority = isError ? .high : .default
        AccessibilityNotification.Announcement(message).post()
    }

    /// Annonce une erreur : priorité haute, la parole en cours est coupée.
    public static func postError(_ text: String) {
        post(text, isError: true)
    }

    /// Vrai quand la valeur passe à un texte non vide, différent du précédent.
    static func shouldAnnounce(from previous: String?, to current: String?) -> Bool {
        guard let current, !current.isEmpty else { return false }
        return current != previous
    }

    /// Vrai quand `message` est un texte non vide et que `id` n'a pas encore été annoncé.
    static func shouldAnnounce(_ message: String?, id: AnyHashable, announced: Set<AnyHashable>) -> Bool {
        guard let message, !message.isEmpty else { return false }
        return !announced.contains(id)
    }
}

private struct AnnounceModifier: ViewModifier {
    let message: String?
    let isError: Bool

    func body(content: Content) -> some View {
        content.onChange(of: message) { previous, current in
            guard let current, PulseAnnouncement.shouldAnnounce(from: previous, to: current) else { return }
            PulseAnnouncement.post(current, isError: isError)
        }
    }
}

private struct AnnounceOnceModifier: ViewModifier {
    private struct Trigger: Equatable {
        let message: String?
        let id: AnyHashable
    }

    let message: String?
    let id: AnyHashable
    let isError: Bool
    @State private var announced: Set<AnyHashable> = []

    func body(content: Content) -> some View {
        content.onChange(of: Trigger(message: message, id: id)) { _, trigger in
            guard let text = trigger.message,
                  PulseAnnouncement.shouldAnnounce(text, id: trigger.id, announced: announced) else { return }
            announced.insert(trigger.id)
            PulseAnnouncement.post(text, isError: isError)
        }
    }
}

public extension View {
    /// Annonce `message` quand il passe à un texte non vide, différent du précédent. À utiliser pour une erreur ou un
    /// résultat qui apparaît sous le focus (`isError` coupe la parole en cours).
    func pulseAnnounce(_ message: String?, isError: Bool = false) -> some View {
        modifier(AnnounceModifier(message: message, isError: isError))
    }

    /// Annonce un message d'erreur dès qu'il apparaît ou change, en priorité haute.
    func pulseAnnounceError(_ message: String?) -> some View {
        pulseAnnounce(message, isError: true)
    }

    /// Annonce `message` une seule fois par `id` (la fin d'un repos, un record) : la même valeur revue ne se répète pas.
    func pulseAnnounceOnce(_ message: String?, id: some Hashable, isError: Bool = false) -> some View {
        modifier(AnnounceOnceModifier(message: message, id: AnyHashable(id), isError: isError))
    }
}
