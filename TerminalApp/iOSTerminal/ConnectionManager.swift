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

class ConnectionManager: ObservableObject {
    static let shared = ConnectionManager()
    
    @Published var connectionStatuses: [UUID: ConnectionStatus] = [:]
    
    // 活跃的 SSH 连接（下滑关闭后保持）
    private var connections: [UUID: SSHConnection] = [:]
    
    // 数据缓冲区（每个服务器最近的输出，用于重新打开时回放）
    private var dataBuffers: [UUID: Data] = [:]
    private let maxBufferSize = 100 * 1024 // 100KB
    
    // 当前显示数据的 TerminalView
    weak var activeTerminalView: SshTerminalView?
    
    private init() {}
    
    // MARK: - 终端视图管理
    
    func registerTerminalView(_ view: SshTerminalView, for serverId: UUID) {
        activeTerminalView = view
        // 回放缓冲区数据
        if let buffer = dataBuffers[serverId], !buffer.isEmpty {
            DispatchQueue.main.async {
                let bytes = [UInt8](buffer)
                view.feed(byteArray: bytes[...])
            }
        }
    }
    
    func unregisterTerminalView(_ view: SshTerminalView) {
        if activeTerminalView === view {
            activeTerminalView = nil
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
            let bytes = [UInt8](data)
            self?.activeTerminalView?.feed(byteArray: bytes[...])
        }
    }
    
    func receiveText(serverId: UUID, text: String) {
        if let data = text.data(using: .utf8) {
            receiveData(serverId: serverId, data: data)
        }
    }
    
    // MARK: - 连接管理
    
    func storeConnection(_ connection: SSHConnection, for serverId: UUID) {
        connections[serverId] = connection
    }
    
    func getConnection(for serverId: UUID) -> SSHConnection? {
        connections[serverId]
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
        connectionStatuses.removeValue(forKey: serverId)
    }
    
    func didError(serverId: UUID, error: String) {
        connectionStatuses[serverId] = .error(error)
        // 3秒后清除错误状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.connectionStatuses[serverId] == .error(error) {
                self?.connectionStatuses[serverId] = .disconnected
            }
        }
    }
    
    func status(for serverId: UUID) -> ConnectionStatus {
        connectionStatuses[serverId] ?? .disconnected
    }
    
    func isConnected(_ serverId: UUID) -> Bool {
        connections[serverId] != nil && connectionStatuses[serverId] == .connected
    }
}
