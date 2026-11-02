import PulseContent
import PulseDomain
import Testing

@Test func everyMuscleBelongsToAGroup() {
    #expect(MuscleGroup(.traps) == .back)
    #expect(MuscleGroup(.rearDelts) == .shoulders)
    #expect(MuscleGroup(.hipFlexors) == .legs)
    #expect(MuscleGroup.allCases.allSatisfy { !$0.localizedName.isEmpty })
}

@Test func muscleGroupsFollowTheSpecMapping() {
    let expected: [MuscleGroup: [Muscle]] = [
        .chest: [.chest],
        .back: [.lats, .upperBack, .lowerBack, .traps],
        .shoulders: [.frontDelts, .sideDelts, .rearDelts],
        .arms: [.biceps, .triceps, .forearms],
        .legs: [.quads, .hamstrings, .glutes, .adductors, .abductors, .calves, .hipFlexors],
        .core: [.abs, .obliques]
    ]
    for (group, muscles) in expected {
        for muscle in muscles { #expect(MuscleGroup(muscle) == group, Comment(rawValue: muscle.rawValue)) }
    }
    #expect(expected.values.flatMap { $0 }.count == Muscle.allCases.count)
}

@Test func muscleGroupsHaveFrenchNames() {
    #expect(MuscleGroup.allCases.map(\.localizedName) == ["Pectoraux", "Dos", "Épaules", "Bras", "Jambes", "Tronc"])
}
