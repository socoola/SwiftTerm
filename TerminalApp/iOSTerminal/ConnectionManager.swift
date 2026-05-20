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
    func disconnect()
}

protocol ConnectionDisconnecting {
    func disconnect(serverId: UUID)
}

class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()
    
    @Published var connectionStatuses: [UUID: ConnectionStatus] = [:]
    
    // 活跃的 SSH 连接（下滑关闭后保持）
    private var connections: [UUID: any ManagedConnection] = [:]
    
    // 数据缓冲区（每个服务器最近的输出，用于重新打开时回放）
    private var dataBuffers: [UUID: Data] = [:]
    private let maxBufferSize = 100 * 1024 // 100KB
    
    // 当前显示数据的 TerminalView
    private weak var activeTerminalOwner: AnyObject?
    private var activeOutputHandler: ((Data) -> Void)?
    private var activeServerId: UUID?
    
    private init() {}
    
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
        connections[serverId] = connection
    }
    
    func getConnection(for serverId: UUID) -> SSHConnection? {
        connections[serverId] as? SSHConnection
    }
    
    func connect(serverId: UUID) {
        connectionStatuses[serverId] = .connecting
    }
    
    func didConnect(serverId: UUID) {
        connectionStatuses[serverId] = .connected
    }
    
    func disconnect(serverId: UUID) {
        if let connection = connections.removeValue(forKey: serverId) {
            connection.disconnect()
        }
        dataBuffers.removeValue(forKey: serverId)
        connectionStatuses[serverId] = .disconnected
        if activeServerId == serverId {
            activeTerminalOwner = nil
            activeOutputHandler = nil
            activeServerId = nil
        }
    }
    
    func didError(serverId: UUID, error: String) {
        connections.removeValue(forKey: serverId)
        connectionStatuses[serverId] = .error(error)
        // 3秒后清除错误状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.connectionStatuses[serverId] == .error(error) {
                self?.connectionStatuses[serverId] = .disconnected
            }
        }
    }
    
    func didDisconnect(serverId: UUID, clearBuffer: Bool = false) {
        connections.removeValue(forKey: serverId)
        if clearBuffer {
            dataBuffers.removeValue(forKey: serverId)
        }
        connectionStatuses[serverId] = .disconnected
        if activeServerId == serverId {
            activeTerminalOwner = nil
            activeOutputHandler = nil
            activeServerId = nil
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
}

extension ConnectionManager: ConnectionDisconnecting {}
