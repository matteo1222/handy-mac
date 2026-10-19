import HandyCore
import Testing

@Test func targetOrderCrossesTheCircleAndVisitsEveryTarget() {
    var test = FittsTest(conditions: [FittsTest.Condition(amplitude: 300, width: 40)])
    var order: [Int] = []
    for _ in 0..<FittsTest.targetCount {
        order.append(test.targetIndex)
        test.select(nil)
    }
    #expect(order.prefix(4) == [0, 7, 1, 8])
    #expect(Set(order).count == FittsTest.targetCount)
}

@Test func throughputFollowsTheEffectiveWidthMethod() throws {
    // Twelve scored 300 pt movements after the starting click, selections ±5 pt along the axis, 0.5 s each.
    let condition = FittsTest.Condition(amplitude: 300, width: 40)
    var test = FittsTest(conditions: [condition])
    test.select(nil)
    let offsets = [-5.0, 5, -5, 5, -5, 5, -5, 5, -5, 5, -5, 5]
    for dx in offsets {
        test.select(
            FittsTest.Trial(
                from: Point(x: 0, y: 0), selection: Point(x: 300 + dx, y: 0), target: Point(x: 300, y: 0),
                seconds: 0.5))
    }
    let result = test.result(input: "synthetic")
    let scored = try #require(result.conditions.first)
    // SD of ±5 over 12 samples (n-1): 5.222; We = 4.133 * 5.222 = 21.58; IDe = log2(300/21.58 + 1) = 3.895
    #expect(abs(scored.effectiveWidth - 21.58) < 0.02)
    #expect(abs(scored.effectiveDifficulty - 3.895) < 0.002)
    #expect(abs(scored.throughput - 7.79) < 0.01)
    #expect(scored.errorRate == 0)
    #expect(test.isFinished)
}

@Test func selectionsOutsideTheTargetCountAsErrors() {
    let condition = FittsTest.Condition(amplitude: 300, width: 40)
    var test = FittsTest(conditions: [condition])
    test.select(nil)
    test.select(FittsTest.Trial(from: .zero, selection: Point(x: 330, y: 0), target: Point(x: 300, y: 0), seconds: 1))
    test.select(FittsTest.Trial(from: .zero, selection: Point(x: 301, y: 0), target: Point(x: 300, y: 0), seconds: 1))
    #expect(test.result(input: "x").conditions.first?.errorRate == 0.5)
}
