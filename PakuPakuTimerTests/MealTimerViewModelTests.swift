import Foundation
import XCTest
@testable import PakuPakuTimer

@MainActor
final class MealTimerViewModelTests: XCTestCase {
    func testRiceEndWaitsForConfirmationInsteadOfAutoAdvancing() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 5 * 60)

        XCTAssertEqual(viewModel.pendingConfirmation?.food, .rice)
        XCTAssertEqual(viewModel.pendingConfirmation?.nextFood, .egg)
        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.activeFood, .egg)
    }

    func testNextFoodResumesFromEgg() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 5 * 60)
        viewModel.goToNextFood()

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.activeFood, .egg)
    }

    func testExtendOneMinuteDoesNotChangeConfiguredMinutes() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 5 * 60)
        viewModel.extendOneMinute()

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.baseMinutes(for: .rice), 5)
        XCTAssertEqual(viewModel.activeExtension?.food, .rice)
        XCTAssertTrue(viewModel.showsExtensionCompletion)
        XCTAssertEqual(viewModel.remainingSeconds(for: .rice), 60, accuracy: 0.001)
    }

    func testFinishButtonIsVisibleOnlyDuringExtension() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        XCTAssertFalse(viewModel.showsExtensionCompletion)

        viewModel.advance(by: 5 * 60)
        XCTAssertFalse(viewModel.showsExtensionCompletion)

        viewModel.extendOneMinute()
        XCTAssertTrue(viewModel.showsExtensionCompletion)
    }

    func testFinishingRiceAndEggExtensionsMovesToNextFood() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 5 * 60)
        viewModel.extendOneMinute()
        viewModel.advance(by: 20)
        viewModel.finishExtension()

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.activeFood, .egg)

        viewModel.advance(by: 5 * 60)
        viewModel.extendOneMinute()
        viewModel.advance(by: 10)
        viewModel.finishExtension()

        XCTAssertTrue(viewModel.isRunning)
        XCTAssertEqual(viewModel.activeFood, .yogurt)
    }

    func testFinishingYogurtExtensionCompletesMeal() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 5 * 60)
        viewModel.goToNextFood()
        viewModel.advance(by: 5 * 60)
        viewModel.goToNextFood()
        viewModel.advance(by: 4 * 60)
        viewModel.extendOneMinute()
        viewModel.advance(by: 12)
        viewModel.finishExtension()

        XCTAssertTrue(viewModel.isComplete)
        XCTAssertNil(viewModel.activeExtension)
    }

    func testYogurtEndWaitsForFeastButton() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 5 * 60)
        viewModel.goToNextFood()
        viewModel.advance(by: 5 * 60)
        viewModel.goToNextFood()
        viewModel.advance(by: 4 * 60)

        XCTAssertEqual(viewModel.pendingConfirmation?.food, .yogurt)
        XCTAssertNil(viewModel.pendingConfirmation?.nextFood)
        XCTAssertFalse(viewModel.isComplete)

        viewModel.goToNextFood()
        XCTAssertTrue(viewModel.isComplete)
    }

    func testPausedConfirmationAndSettingsTimeIsNotSpentTime() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 10)
        viewModel.pause()
        viewModel.advance(by: 30)
        XCTAssertEqual(spent(.rice, in: viewModel), 10, accuracy: 0.001)

        viewModel.start()
        viewModel.advance(by: 290)
        XCTAssertEqual(viewModel.pendingConfirmation?.food, .rice)
        viewModel.advance(by: 30)
        XCTAssertEqual(spent(.rice, in: viewModel), 300, accuracy: 0.001)

        viewModel.openSettings()
        viewModel.advance(by: 40)
        viewModel.commitSettings()
        XCTAssertEqual(spent(.rice, in: viewModel), 300, accuracy: 0.001)
    }

    func testLargeTimeJumpStopsAtFirstBoundary() {
        let viewModel = MealTimerViewModel()

        viewModel.start()
        viewModel.advance(by: 14 * 60 + 20)

        XCTAssertEqual(viewModel.pendingConfirmation?.food, .rice)
        XCTAssertEqual(viewModel.elapsedSeconds, 5 * 60, accuracy: 0.001)
        XCTAssertEqual(spent(.rice, in: viewModel), 5 * 60, accuracy: 0.001)
        XCTAssertEqual(spent(.egg, in: viewModel), 0, accuracy: 0.001)
        XCTAssertEqual(spent(.yogurt, in: viewModel), 0, accuracy: 0.001)
    }

    func testSettingsChangeClearsTestConfirmationAndExtensionState() {
        let viewModel = MealTimerViewModel()

        viewModel.enableTestMode()
        viewModel.start()
        viewModel.advance(by: 5)
        viewModel.extendOneMinute()

        XCTAssertTrue(viewModel.testMode)
        XCTAssertNotNil(viewModel.activeExtension)

        viewModel.openSettings()
        viewModel.updateDraftMinutes(6, for: .rice)
        viewModel.commitSettings()

        XCTAssertFalse(viewModel.testMode)
        XCTAssertNil(viewModel.pendingConfirmation)
        XCTAssertNil(viewModel.activeExtension)
        XCTAssertEqual(viewModel.baseMinutes(for: .rice), 6)
        XCTAssertFalse(viewModel.showsExtensionCompletion)
    }

    private func spent(_ food: FoodKind, in viewModel: MealTimerViewModel) -> TimeInterval {
        viewModel.spentSecondsByFood[food] ?? 0
    }
}
