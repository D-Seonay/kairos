import PulseServices
import Testing

/// Le journal des étapes franchies par les opérations, dans l'ordre où elles arrivent.
private actor StepLog {
    private(set) var steps: [String] = []

    func append(_ step: String) {
        steps.append(step)
    }
}

private struct Boom: Error {}

struct SerialTaskQueueTests {
    @Test func operationsRunOneAtATimeInOrder() async throws {
        let queue = SerialTaskQueue()
        let gate = Gate()
        let log = StepLog()
        let first = Task {
            try await queue.run {
                await log.append("first starts")
                await gate.pass()
                await log.append("first ends")
            }
        }
        await gate.waitForArrival()
        let second = Task {
            try await queue.run { await log.append("second") }
        }
        for _ in 0..<100 { await Task.yield() }
        #expect(await log.steps == ["first starts"])

        await gate.open()
        try await first.value
        try await second.value
        #expect(await log.steps == ["first starts", "first ends", "second"])
    }

    @Test func aFailureDoesNotBlockTheNext() async throws {
        let queue = SerialTaskQueue()
        await #expect(throws: Boom.self) {
            try await queue.run { () async throws -> Int in throw Boom() }
        }
        #expect(try await queue.run { 42 } == 42)
    }
}
