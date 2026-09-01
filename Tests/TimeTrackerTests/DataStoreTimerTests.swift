import XCTest
@testable import TimeTracker

final class DataStoreTimerTests: XCTestCase {
    private var temporaryRoot: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        defaultsSuiteName = "TimeTrackerTimerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)

        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTimerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try FileManager.default.removeItem(at: temporaryRoot)
    }

    func testPausedTimeIsExcludedAndNotesAreSavedToEntry() throws {
        let store = makeStore()
        let clientId = UUID()
        let projectId = UUID()
        let start = Date(timeIntervalSince1970: 1_000)

        store.startTimer(clientId: clientId, projectId: projectId, at: start)
        store.updateRunningNotes("Preparing the first draft")
        store.pauseTimer(at: start.addingTimeInterval(600))

        XCTAssertTrue(store.isRunning)
        XCTAssertTrue(store.isPaused)
        XCTAssertEqual(store.elapsedDuration(at: start.addingTimeInterval(1_200)), 600, accuracy: 0.001)

        let entry = try XCTUnwrap(store.stopTimer(at: start.addingTimeInterval(1_800)))
        XCTAssertEqual(entry.durationSeconds, 600, accuracy: 0.001)
        XCTAssertEqual(entry.notes, "Preparing the first draft")
        XCTAssertFalse(store.isRunning)
        XCTAssertFalse(store.isPaused)
        XCTAssertEqual(store.runningNotes, "")
    }

    func testResumeContinuesFromAccumulatedElapsedTime() throws {
        let store = makeStore()
        let start = Date(timeIntervalSince1970: 2_000)

        store.startTimer(clientId: UUID(), projectId: UUID(), at: start)
        store.pauseTimer(at: start.addingTimeInterval(600))
        store.resumeTimer(at: start.addingTimeInterval(900))

        let entry = try XCTUnwrap(store.stopTimer(at: start.addingTimeInterval(1_500)))
        XCTAssertEqual(entry.durationSeconds, 1_200, accuracy: 0.001)
    }

    func testPausedTimerAndNotesRestoreAfterRelaunch() throws {
        let clientId = UUID()
        let projectId = UUID()
        let start = Date(timeIntervalSince1970: 3_000)
        var store: DataStore? = makeStore()

        store?.startTimer(clientId: clientId, projectId: projectId, at: start)
        store?.updateRunningNotes("Research and references")
        store?.pauseTimer(at: start.addingTimeInterval(420))
        store = nil

        let restoredStore = makeStore()
        XCTAssertTrue(restoredStore.isRunning)
        XCTAssertTrue(restoredStore.isPaused)
        XCTAssertEqual(restoredStore.runningClientId, clientId)
        XCTAssertEqual(restoredStore.runningProjectId, projectId)
        XCTAssertEqual(restoredStore.runningNotes, "Research and references")
        XCTAssertEqual(restoredStore.elapsedDuration(at: start.addingTimeInterval(900)), 420, accuracy: 0.001)
    }

    private func makeStore() -> DataStore {
        DataStore(
            defaults: defaults,
            applicationSupportDirectory: temporaryRoot.appendingPathComponent("Support", isDirectory: true)
        )
    }
}
