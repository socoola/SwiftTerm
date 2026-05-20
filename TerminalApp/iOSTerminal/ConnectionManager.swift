//
//  ConnectionManager.swift
//  iOSTerminal
//
//  Created by Assistant on 1/20/25.
//

import Foundation
import Combine

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

protocol ManagedConnection: AnyObject {
    var connectionId: UUID { get }
    func disconnect()
}

protocol ConnectionDisconnecting {
    func disconnect(serverId: UUID)
}

class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()
    
    @Published var connectionStatuses: [UUID: ConnectionStatus] = [:]
    
    // 活跃的 SSH 连接（下滑关闭后保持）
    private struct StoredConnection {
        let id: UUID
        let connection: any ManagedConnection
    }

    private var connections: [UUID: StoredConnection] = [:]
    
    // 数据缓冲区（每个服务器最近的输出，用于重新打开时回放）
    private var dataBuffers: [UUID: Data] = [:]
    private let maxBufferSize = 100 * 1024 // 100KB
    
    // 当前显示数据的 TerminalView
    private weak var activeTerminalOwner: AnyObject?
    private var activeOutputHandler: ((Data) -> Void)?
    private var activeServerId: UUID?
    
    private init() {}

    private func performStateUpdate(_ update: @escaping () -> Void) {
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }
    
    // MARK: - 终端视图管理
    
    func registerTerminalView(_ view: SshTerminalView, for serverId: UUID) {
        registerOutputHandler(owner: view, for: serverId) { [weak view] data in
            let bytes = [UInt8](data)
            view?.feed(byteArray: bytes[...])
        }
    }
    
    func registerOutputHandler(owner: AnyObject, for serverId: UUID, outputHandler: @escaping (Data) -> Void) {
        activeTerminalOwner = owner
        activeOutputHandler = outputHandler
        activeServerId = serverId
        // 回放缓冲区数据
        if let buffer = dataBuffers[serverId], !buffer.isEmpty {
            DispatchQueue.main.async {
                outputHandler(buffer)
            }
        }
    }
    
    func unregisterTerminalView(_ view: SshTerminalView) {
        unregisterOutputHandler(owner: view)
    }
    
    func unregisterOutputHandler(owner: AnyObject) {
        if activeTerminalOwner === owner {
            activeTerminalOwner = nil
            activeOutputHandler = nil
            activeServerId = nil
        }
    }
    
    // MARK: - 数据接收
    
    func receiveData(serverId: UUID, data: Data) {
        // 更新缓冲区
        var buffer = dataBuffers[serverId] ?? Data()
        buffer.append(data)
        if buffer.count > maxBufferSize {
            buffer = Data(buffer.suffix(maxBufferSize))
        }
        dataBuffers[serverId] = buffer
        
        // 转发给当前活跃的终端视图
        DispatchQueue.main.async { [weak self] in
            guard self?.activeServerId == serverId else { return }
            self?.activeOutputHandler?(data)
        }
    }
    
    func receiveText(serverId: UUID, text: String) {
        if let data = text.data(using: .utf8) {
            receiveData(serverId: serverId, data: data)
        }
    }
    
    // MARK: - 连接管理
    
    func storeConnection(_ connection: any ManagedConnection, for serverId: UUID) {
        performStateUpdate {
            self.connections[serverId] = StoredConnection(id: connection.connectionId, connection: connection)
        }
    }
    
    func getConnection(for serverId: UUID) -> SSHConnection? {
        connections[serverId]?.connection as? SSHConnection
    }
    
    func connect(serverId: UUID, connectionId: UUID? = nil) {
        performStateUpdate {
            guard self.matchesCurrentConnection(serverId: serverId, connectionId: connectionId) else { return }
            self.connectionStatuses[serverId] = .connecting
        }
    }
    
    func didConnect(serverId: UUID, connectionId: UUID? = nil) {
        performStateUpdate {
            guard self.matchesCurrentConnection(serverId: serverId, connectionId: connectionId) else { return }
            self.connectionStatuses[serverId] = .connected
        }
    }
    
    func disconnect(serverId: UUID) {
        performStateUpdate {
            if let connection = self.connections.removeValue(forKey: serverId) {
                connection.connection.disconnect()
            }
            self.dataBuffers.removeValue(forKey: serverId)
            self.connectionStatuses[serverId] = .disconnected
            if self.activeServerId == serverId {
                self.activeTerminalOwner = nil
                self.activeOutputHandler = nil
                self.activeServerId = nil
            }
        }
    }
    
    func didError(serverId: UUID, connectionId: UUID? = nil, error: String) {
        performStateUpdate {
            guard self.matchesCurrentConnection(serverId: serverId, connectionId: connectionId) else { return }
            self.connections.removeValue(forKey: serverId)
            self.connectionStatuses[serverId] = .error(error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.connectionStatuses[serverId] == .error(error) {
                    self?.connectionStatuses[serverId] = .disconnected
                }
            }
        }
    }
    
    func didDisconnect(serverId: UUID, connectionId: UUID? = nil, clearBuffer: Bool = false) {
        performStateUpdate {
            guard self.matchesCurrentConnection(serverId: serverId, connectionId: connectionId) else { return }
            self.connections.removeValue(forKey: serverId)
            if clearBuffer {
                self.dataBuffers.removeValue(forKey: serverId)
            }
            self.connectionStatuses[serverId] = .disconnected
            if self.activeServerId == serverId {
                self.activeTerminalOwner = nil
                self.activeOutputHandler = nil
                self.activeServerId = nil
            }
        }
    }
    
    func status(for serverId: UUID) -> ConnectionStatus {
        connectionStatuses[serverId] ?? .disconnected
    }
    
    func isConnected(_ serverId: UUID) -> Bool {
        connections[serverId] != nil && connectionStatuses[serverId] == .connected
    }
    
    func resetForTesting() {
        connections.removeAll()
        dataBuffers.removeAll()
        connectionStatuses.removeAll()
        activeTerminalOwner = nil
        activeOutputHandler = nil
        activeServerId = nil
    }

    private func matchesCurrentConnection(serverId: UUID, connectionId: UUID?) -> Bool {
        guard let connectionId else { return true }
        return connections[serverId]?.id == connectionId
    }
}

extension ConnectionManager: ConnectionDisconnecting {}
