import XCTest
@testable import iOSTerminal

final class ConnectionFlowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ConnectionManager.shared.resetForTesting()
    }

    override func tearDown() {
        ConnectionManager.shared.resetForTesting()
        super.tearDown()
    }

    func testReceiveDataOnlyFeedsActiveServer() {
        let serverA = UUID()
        let serverB = UUID()
        let sinkA = OutputSink()
        let sinkB = OutputSink()

        ConnectionManager.shared.registerOutputHandler(owner: sinkA, for: serverA) { data in
            sinkA.outputs.append(String(decoding: data, as: UTF8.self))
        }
        ConnectionManager.shared.receiveText(serverId: serverA, text: "A1")
        drainMainQueue()

        ConnectionManager.shared.registerOutputHandler(owner: sinkB, for: serverB) { data in
            sinkB.outputs.append(String(decoding: data, as: UTF8.self))
        }
        ConnectionManager.shared.receiveText(serverId: serverA, text: "A2")
        ConnectionManager.shared.receiveText(serverId: serverB, text: "B1")
        drainMainQueue()

        XCTAssertEqual(sinkA.outputs, ["A1"])
        XCTAssertEqual(sinkB.outputs, ["B1"])
    }

    func testDisconnectRemovesStoredConnectionAndMarksDisconnected() {
        let serverId = UUID()
        let connection = FakeConnection()

        ConnectionManager.shared.storeConnection(connection, for: serverId)
        ConnectionManager.shared.didConnect(serverId: serverId, connectionId: connection.connectionId)
        drainMainQueue()

        XCTAssertTrue(ConnectionManager.shared.isConnected(serverId))

        ConnectionManager.shared.disconnect(serverId: serverId)
        drainMainQueue()

        XCTAssertTrue(connection.didDisconnect)
        XCTAssertEqual(ConnectionManager.shared.status(for: serverId), .disconnected)
        XCTAssertFalse(ConnectionManager.shared.isConnected(serverId))
    }

    func testDidErrorRemovesDeadConnectionImmediately() {
        let serverId = UUID()
        let connection = FakeConnection()

        ConnectionManager.shared.storeConnection(connection, for: serverId)
        ConnectionManager.shared.didConnect(serverId: serverId, connectionId: connection.connectionId)
        drainMainQueue()

        ConnectionManager.shared.didError(serverId: serverId, connectionId: connection.connectionId, error: "boom")
        drainMainQueue()

        XCTAssertEqual(ConnectionManager.shared.status(for: serverId), .error("boom"))
        XCTAssertFalse(ConnectionManager.shared.isConnected(serverId))
    }

    func testStaleDisconnectDoesNotOverrideNewConnectionStatus() {
        let serverId = UUID()
        let oldConnection = FakeConnection()
        let newConnection = FakeConnection()

        ConnectionManager.shared.storeConnection(oldConnection, for: serverId)
        ConnectionManager.shared.didConnect(serverId: serverId, connectionId: oldConnection.connectionId)
        ConnectionManager.shared.storeConnection(newConnection, for: serverId)
        ConnectionManager.shared.connect(serverId: serverId, connectionId: newConnection.connectionId)
        ConnectionManager.shared.didDisconnect(serverId: serverId, connectionId: oldConnection.connectionId)
        ConnectionManager.shared.didConnect(serverId: serverId, connectionId: newConnection.connectionId)
        drainMainQueue()

        XCTAssertEqual(ConnectionManager.shared.status(for: serverId), .connected)
        XCTAssertTrue(ConnectionManager.shared.isConnected(serverId))
    }

    func testQuickConnectDisconnectHelperDisconnectsAndClearsSession() {
        let serverId = UUID()
        let recorder = DisconnectRecorder()
        let info = SSHConnectionInfo(
            serverId: serverId,
            host: "127.0.0.1",
            username: "test",
            password: "secret"
        )

        let result = SSHLoginView.disconnectSession(info, using: recorder)

        XCTAssertNil(result)
        XCTAssertEqual(recorder.disconnectedServerIds, [serverId])
    }

    func testDeleteServerHelperDisconnectsBeforeDeleting() {
        let recorder = DisconnectRecorder()
        let store = DeletionRecorder()
        let server = SSHServer(
            id: UUID(),
            name: "A",
            host: "127.0.0.1",
            username: "u",
            password: "p"
        )

        ServerListView.deleteServer(server, store: store, connectionManager: recorder)

        XCTAssertEqual(recorder.disconnectedServerIds, [server.id])
        XCTAssertEqual(store.deletedServers, [server])
    }

    private func drainMainQueue(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = expectation(description: "main queue drained")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

private final class OutputSink: NSObject {
    var outputs: [String] = []
}

private final class FakeConnection: ManagedConnection {
    let connectionId = UUID()
    private(set) var didDisconnect = false

    func disconnect() {
        didDisconnect = true
    }
}

private final class DisconnectRecorder: ConnectionDisconnecting {
    private(set) var disconnectedServerIds: [UUID] = []

    func disconnect(serverId: UUID) {
        disconnectedServerIds.append(serverId)
    }
}

private final class DeletionRecorder: ServerDeleting {
    private(set) var deletedServers: [SSHServer] = []

    func delete(_ server: SSHServer) {
        deletedServers.append(server)
    }
}
