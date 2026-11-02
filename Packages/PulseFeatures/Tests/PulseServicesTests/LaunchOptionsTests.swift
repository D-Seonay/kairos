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
        #expect(LaunchOptions.parse(["Pulse"]) == LaunchOptions())
    }

    @Test func unknownValuesAreIgnored() {
        let options = LaunchOptions.parse(["Pulse", "-PulseStore", "nope", "-PulseNow", "demain", "-PulseHealthScenario",
                                           "-PulseResetStore", "NO", "-PulseSeed", "inconnu"])
        #expect(options == LaunchOptions())
    }

    @Test func diskStoreResetAndSeedAreRead() {
        let options = LaunchOptions.parse(["Pulse", "-PulseStore", "disk", "-PulseResetStore", "YES", "-PulseSeed", "onboardedPPL"])
        #expect(options.storeOnDisk && !options.storeInMemory)
        #expect(options.resetsStore)
        #expect(options.seed == .onboardedPPL)
    }

    @Test func eachStoreOptionIsReadOnItsOwn() {
        #expect(LaunchOptions.parse(["Pulse", "-PulseStore", "inMemory"]).storeInMemory)
        let disk = LaunchOptions.parse(["Pulse", "-PulseStore", "disk"])
        #expect(disk.storeOnDisk && !disk.resetsStore && disk.seed == nil)
    }
}
