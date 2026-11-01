import PulseServices
import Testing

struct LaunchOptionsTests {
    @Test func launchOptionsParse() {
        let options = LaunchOptions.parse(["Pulse", "-PulseStore", "inMemory", "-PulseHealthScenario", "badNight",
                                           "-PulseNow", "2026-11-02T08:00:00+01:00"])
        #expect(options.storeInMemory && options.healthScenario == .badNight && options.fixedNow != nil)
        #expect(LaunchOptions.parse(["Pulse", "-PulseHealthScenario", "nope"]).healthScenario == nil)
    }

    @Test func emptyArgumentsGiveDefaults() {
        #expect(LaunchOptions.parse(["Pulse"]) == LaunchOptions(storeInMemory: false, healthScenario: nil, fixedNow: nil))
    }

    @Test func unknownValuesAreIgnored() {
        let options = LaunchOptions.parse(["Pulse", "-PulseStore", "disk", "-PulseNow", "demain", "-PulseHealthScenario"])
        #expect(options == LaunchOptions(storeInMemory: false, healthScenario: nil, fixedNow: nil))
    }
}
