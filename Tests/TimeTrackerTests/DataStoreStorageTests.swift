import XCTest
@testable import TimeTracker

final class DataStoreStorageTests: XCTestCase {
    private var temporaryRoot: URL!
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUpWithError() throws {
        defaultsSuiteName = "TimeTrackerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)

        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeTrackerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try FileManager.default.removeItem(at: temporaryRoot)
    }

    func testMovesCurrentDataToSyncedFolderAndRestoresIt() throws {
        let supportDirectory = temporaryRoot.appendingPathComponent("Support", isDirectory: true)
        let syncedDirectory = temporaryRoot.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: syncedDirectory, withIntermediateDirectories: true)

        var store: DataStore? = DataStore(
            defaults: defaults,
            applicationSupportDirectory: supportDirectory
        )
        store?.addClient(name: "Acme")

        try store?.connectStorage(
            to: syncedDirectory,
            existingDatabaseChoice: .replaceWithCurrent
        )

        let syncedFile = syncedDirectory.appendingPathComponent(DataStore.syncedDatabaseFilename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: syncedFile.path))
        XCTAssertEqual(store?.databaseURL.standardizedFileURL, syncedFile.standardizedFileURL)
        store = nil

        let restoredStore = DataStore(
            defaults: defaults,
            applicationSupportDirectory: supportDirectory
        )
        XCTAssertTrue(restoredStore.isUsingCustomStorage)
        XCTAssertEqual(restoredStore.clients.map(\.name), ["Acme"])
    }

    func testCanOpenAnExistingSyncedDatabaseWithoutReplacingIt() throws {
        let syncedDirectory = temporaryRoot.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: syncedDirectory, withIntermediateDirectories: true)

        let firstSupportDirectory = temporaryRoot.appendingPathComponent("Support-A", isDirectory: true)
        let firstStore = DataStore(
            defaults: defaults,
            applicationSupportDirectory: firstSupportDirectory
        )
        firstStore.addClient(name: "Cloud Client")
        try firstStore.connectStorage(
            to: syncedDirectory,
            existingDatabaseChoice: .replaceWithCurrent
        )

        let secondDefaultsName = "TimeTrackerTests.\(UUID().uuidString)"
        let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: secondDefaultsName))
        defer { secondDefaults.removePersistentDomain(forName: secondDefaultsName) }

        let secondSupportDirectory = temporaryRoot.appendingPathComponent("Support-B", isDirectory: true)
        let secondStore = DataStore(
            defaults: secondDefaults,
            applicationSupportDirectory: secondSupportDirectory
        )
        secondStore.addClient(name: "Local Client")
        try secondStore.connectStorage(
            to: syncedDirectory,
            existingDatabaseChoice: .useExisting
        )

        XCTAssertEqual(secondStore.clients.map(\.name), ["Cloud Client"])
    }

    func testReturningToLocalStorageCopiesCurrentDataAndKeepsCloudFile() throws {
        let supportDirectory = temporaryRoot.appendingPathComponent("Support", isDirectory: true)
        let syncedDirectory = temporaryRoot.appendingPathComponent("Cloud", isDirectory: true)
        try FileManager.default.createDirectory(at: syncedDirectory, withIntermediateDirectories: true)

        let store = DataStore(
            defaults: defaults,
            applicationSupportDirectory: supportDirectory
        )
        store.addClient(name: "Copied Client")
        try store.connectStorage(
            to: syncedDirectory,
            existingDatabaseChoice: .replaceWithCurrent
        )

        let syncedFile = syncedDirectory.appendingPathComponent(DataStore.syncedDatabaseFilename)
        try store.returnToLocalStorage()

        XCTAssertFalse(store.isUsingCustomStorage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.databaseURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: syncedFile.path))

        let localStore = DataStore(
            defaults: UserDefaults(suiteName: "TimeTrackerTests.local.\(UUID().uuidString)")!,
            applicationSupportDirectory: supportDirectory
        )
        XCTAssertEqual(localStore.clients.map(\.name), ["Copied Client"])
    }
}
