import Foundation

struct BoundaryConfirmation: Equatable {
    let food: FoodKind
    let nextFood: FoodKind?
    let boundaryElapsed: TimeInterval
}

enum MealTimerPhase: Equatable {
    case idle
    case running
    case paused
    case awaitingConfirmation(BoundaryConfirmation)
    case setting
    case completed
}

@MainActor
final class MealTimerViewModel: ObservableObject {
    @Published private(set) var phase: MealTimerPhase = .idle
    @Published private(set) var minutesByFood: [FoodKind: Int]
    @Published var draftMinutesByFood: [FoodKind: Int]
    @Published private(set) var testMode = false
    @Published var soundEnabled = true
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var spentSecondsByFood: [FoodKind: TimeInterval]
    @Published private(set) var activeExtension: BoundaryConfirmation?

    private var extraSecondsByFood: [FoodKind: TimeInterval] = [:]
    private var phaseBeforeSettings: MealTimerPhase = .idle

    init() {
        let defaults = Dictionary(uniqueKeysWithValues: FoodKind.allCases.map { ($0, $0.defaultMinutes) })
        minutesByFood = defaults
        draftMinutesByFood = defaults
        spentSecondsByFood = Dictionary(uniqueKeysWithValues: FoodKind.allCases.map { ($0, 0) })
    }

    var isRunning: Bool {
        phase == .running
    }

    var isComplete: Bool {
        phase == .completed
    }

    var pendingConfirmation: BoundaryConfirmation? {
        if case let .awaitingConfirmation(confirmation) = phase {
            return confirmation
        }
        return nil
    }

    var showsExtensionCompletion: Bool {
        activeExtension != nil && phase == .running
    }

    var totalSeconds: TimeInterval {
        FoodKind.eatingOrder.reduce(0) { $0 + duration(for: $1) }
    }

    var remainingTotalSeconds: TimeInterval {
        max(0, totalSeconds - elapsedSeconds)
    }

    var activeFood: FoodKind? {
        progress(at: elapsedSeconds).food
    }

    func duration(for food: FoodKind) -> TimeInterval {
        let baseSeconds = TimeInterval(testMode ? 5 : (minutesByFood[food] ?? food.defaultMinutes) * 60)
        return baseSeconds + (extraSecondsByFood[food] ?? 0)
    }

    func baseMinutes(for food: FoodKind) -> Int {
        minutesByFood[food] ?? food.defaultMinutes
    }

    func remainingSeconds(for food: FoodKind) -> TimeInterval {
        let bounds = boundsByFood()
        guard let range = bounds[food] else { return 0 }
        let consumed = min(max(elapsedSeconds - range.lowerBound, 0), range.upperBound - range.lowerBound)
        return max(0, range.upperBound - range.lowerBound - consumed)
    }

    func progressRatio(for food: FoodKind) -> Double {
        let duration = duration(for: food)
        guard duration > 0 else { return 1 }
        return min(1, max(0, (duration - remainingSeconds(for: food)) / duration))
    }

    func start() {
        guard pendingConfirmation == nil else { return }
        if phase == .completed || elapsedSeconds >= totalSeconds {
            resetDynamicState()
        }
        phase = .running
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
    }

    func reset() {
        testMode = false
        resetDynamicState()
        phase = .idle
    }

    func enableTestMode() {
        testMode = true
        resetDynamicState()
        phase = .idle
    }

    func advance(by seconds: TimeInterval) {
        guard phase == .running, seconds > 0 else { return }

        let previousElapsed = elapsedSeconds
        let proposedElapsed = min(previousElapsed + seconds, totalSeconds)

        if let boundary = firstCrossedBoundary(from: previousElapsed, to: proposedElapsed) {
            let movedSeconds = max(0, boundary.boundaryElapsed - previousElapsed)
            spentSecondsByFood[boundary.food, default: 0] += movedSeconds
            elapsedSeconds = boundary.boundaryElapsed
            activeExtension = nil
            phase = .awaitingConfirmation(boundary)
            return
        }

        if let food = progress(at: previousElapsed).food {
            spentSecondsByFood[food, default: 0] += max(0, proposedElapsed - previousElapsed)
        }
        elapsedSeconds = proposedElapsed
    }

    func goToNextFood() {
        guard let confirmation = pendingConfirmation else { return }
        elapsedSeconds = confirmation.boundaryElapsed
        if confirmation.nextFood == nil {
            completeMeal()
        } else {
            phase = .running
        }
    }

    func extendOneMinute() {
        guard let confirmation = pendingConfirmation else { return }
        extraSecondsByFood[confirmation.food, default: 0] += 60
        activeExtension = confirmation
        phase = .running
    }

    func finishExtension() {
        guard let currentExtension = activeExtension else { return }
        extraSecondsByFood[currentExtension.food] = nil
        elapsedSeconds = currentExtension.boundaryElapsed
        activeExtension = nil

        if currentExtension.nextFood == nil {
            completeMeal()
        } else {
            phase = .running
        }
    }

    func openSettings() {
        if phase != .setting {
            phaseBeforeSettings = phase == .running ? .paused : phase
        }
        draftMinutesByFood = minutesByFood
        if phase == .running {
            phaseBeforeSettings = .paused
        }
        phase = .setting
    }

    func updateDraftMinutes(_ minutes: Int, for food: FoodKind) {
        draftMinutesByFood[food] = min(60, max(1, minutes))
    }

    func commitSettings() {
        let normalized = Dictionary(uniqueKeysWithValues: FoodKind.allCases.map {
            ($0, min(60, max(1, draftMinutesByFood[$0] ?? $0.defaultMinutes)))
        })
        let changed = normalized != minutesByFood
        if changed {
            minutesByFood = normalized
            testMode = false
            activeExtension = nil
            extraSecondsByFood.removeAll()
            spentSecondsByFood = Dictionary(uniqueKeysWithValues: FoodKind.allCases.map { ($0, 0) })
            elapsedSeconds = min(elapsedSeconds, totalSeconds)
            phase = elapsedSeconds > 0 ? .paused : .idle
        } else {
            phase = phaseBeforeSettings
        }
    }

    func toggleSound() {
        soundEnabled.toggle()
    }

    func formattedRemaining(_ seconds: TimeInterval) -> String {
        "\(max(0, Int(ceil(seconds / 60))))分"
    }

    func formattedSpent(_ seconds: TimeInterval) -> String {
        let rounded = max(0, Int(seconds.rounded()))
        let minutes = rounded / 60
        let secondsPart = rounded % 60

        if minutes == 0 {
            return "\(secondsPart)秒"
        }
        if secondsPart == 0 {
            return "\(minutes)分"
        }
        return "\(minutes)分\(secondsPart)秒"
    }

    private func completeMeal() {
        phase = .completed
    }

    private func resetDynamicState() {
        elapsedSeconds = 0
        activeExtension = nil
        extraSecondsByFood.removeAll()
        spentSecondsByFood = Dictionary(uniqueKeysWithValues: FoodKind.allCases.map { ($0, 0) })
    }

    private func firstCrossedBoundary(from previousElapsed: TimeInterval, to nextElapsed: TimeInterval) -> BoundaryConfirmation? {
        var cursor: TimeInterval = 0
        for (index, food) in FoodKind.eatingOrder.enumerated() {
            cursor += duration(for: food)
            if previousElapsed < cursor && nextElapsed >= cursor {
                return BoundaryConfirmation(
                    food: food,
                    nextFood: FoodKind.eatingOrder.indices.contains(index + 1) ? FoodKind.eatingOrder[index + 1] : nil,
                    boundaryElapsed: cursor
                )
            }
        }
        return nil
    }

    private func progress(at elapsed: TimeInterval) -> (food: FoodKind?, elapsedInFood: TimeInterval) {
        var cursor: TimeInterval = 0
        for food in FoodKind.eatingOrder {
            let start = cursor
            let end = start + duration(for: food)
            if elapsed < end {
                return (food, max(0, elapsed - start))
            }
            cursor = end
        }
        return (nil, 0)
    }

    private func boundsByFood() -> [FoodKind: Range<TimeInterval>] {
        var cursor: TimeInterval = 0
        var result: [FoodKind: Range<TimeInterval>] = [:]
        for food in FoodKind.eatingOrder {
            let end = cursor + duration(for: food)
            result[food] = cursor..<end
            cursor = end
        }
        return result
    }
}
