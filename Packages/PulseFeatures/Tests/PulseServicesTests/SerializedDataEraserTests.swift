import PulseDomain
import PulseServices
import Testing

/// Un effaceur qui note ses appels et ce que le widget avait déjà reçu à ce moment-là.
actor RecordingEraser: DataEraser {
    private let widgets: StubWidgetPublisher
    private(set) var calls: [EraseOptions] = []
    private(set) var publishedAtErase: Int?

    init(widgets: StubWidgetPublisher) {
        self.widgets = widgets
    }

    func eraseEverything(options: EraseOptions) async throws {
        calls.append(options)
        publishedAtErase = await widgets.published.count
    }
}

struct SerializedDataEraserTests {
    /// La publication de l'instantané est suspendue : sans file, la suppression passerait avant elle, et le widget
    /// recevrait le score après l'effacement.
    @Test func eraseWaitsForTheRunningRefresh() async throws {
        let gate = Gate()
        let fixture = RefresherFixture(scenario: .goodNight, holdingPublishesAt: gate)
        try await fixture.adopt()
        let inner = RecordingEraser(widgets: fixture.widgets)
        let eraser = SerializedDataEraser(refresher: fixture.refresher, inner: inner)

        async let refresh = fixture.refresher.refresh(origin: .foreground)
        await gate.waitForArrival()
        async let erase: Void = eraser.eraseEverything(options: EraseOptions(includeAppleHealth: true))
        try await Task.sleep(for: .milliseconds(100))
        #expect(await inner.calls.isEmpty)
        await gate.open()
        _ = await refresh
        try await erase

        #expect(await inner.calls == [EraseOptions(includeAppleHealth: true)])
        let published = await fixture.widgets.published.count
        #expect(published == 1)
        #expect(await inner.publishedAtErase == published)
    }
}
