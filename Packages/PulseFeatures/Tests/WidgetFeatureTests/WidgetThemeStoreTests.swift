import Foundation
import PulseDomain
import Testing
@testable import WidgetFeature

/// L'ambiance partagée avec les widgets : Ivoire par défaut, réécrite seulement quand elle change, effacée avec les données.
struct WidgetThemeStoreTests {
    /// Une suite neuve par test, vidée à la fin : jamais les préférences du groupe d'apps.
    private func withStore(_ body: (WidgetThemeStore, UserDefaults) throws -> Void) rethrows {
        let suiteName = "fr.seonay.pulse.tests.widget-theme.\(UUID().uuidString)"
        defer { UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName) }
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Suite de préférences indisponible")
            return
        }
        try body(WidgetThemeStore(suiteName: suiteName), defaults)
    }

    @Test func nothingWrittenReadsIvory() {
        withStore { store, _ in
            #expect(store.read() == .amber)
        }
    }

    @Test func writingReportsOnlyAChange() {
        withStore { store, _ in
            #expect(store.write(.amethyst))
            #expect(store.read() == .amethyst)
            #expect(!store.write(.amethyst))
            #expect(store.write(.amber))
            #expect(store.read() == .amber)
        }
    }

    @Test func clearingGoesBackToIvory() {
        withStore { store, _ in
            store.write(.amethyst)
            store.clear()
            #expect(store.read() == .amber)
        }
    }

    @Test func anUnknownValueReadsIvory() {
        withStore { store, defaults in
            defaults.set("sépia", forKey: WidgetThemeStore.key)
            #expect(store.read() == .amber)
            // Une valeur inconnue n'est pas l'ambiance demandée : l'écrire la remplace.
            #expect(store.write(.amber))
        }
    }
}
