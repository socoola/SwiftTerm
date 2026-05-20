//
//  UIKitSshTerminalView.swift
//  iOS
//
//  Created by Miguel de Icaza on 4/22/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import UIKit
import SwiftTerm
import NIOCore
import NIOPosix
import NIOSSH

struct SSHConnectionInfo: Equatable {
    let serverId: UUID
    let host: String
    let port: Int
    let username: String
    let password: String
    let startupScript: String?
    let term: String
    let environment: [String: String]

    init(
        serverId: UUID = UUID(),
        host: String,
        port: Int = 22,
        username: String,
        password: String,
        startupScript: String? = nil,
        term: String = "xterm-256color",
        environment: [String: String] = ["LANG": "en_US.UTF-8"]
    ) {
        self.serverId = serverId
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.startupScript = startupScript
        self.term = term
        self.environment = environment
    }

    var preparedStartupScript: String? {
        let trimmed = startupScript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasSuffix("\n") ? trimmed : trimmed + "\n"
    }
}

private enum SSHClientError: Error {
    case invalidChannelType
}

private final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}

private final class SimplePasswordDelegate: NIOSSHClientUserAuthenticationDelegate {
    let username: String
    let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(availableMethods: NIOSSHAvailableUserAuthenticationMethods, nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>) {
        guard availableMethods.contains(.password) else {
            print("[SSH-Auth] Password auth not available, methods: \(availableMethods)")
            nextChallengePromise.fail(SSHClientError.invalidChannelType)
            return
        }
        print("[SSH-Auth] Sending password for user: \(username)")
        let offer = NIOSSHUserAuthenticationOffer(
            username: username,
            serviceName: "",
            offer: .password(.init(password: password))
        )
        nextChallengePromise.succeed(offer)
    }
}

private final class SSHErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any

    private let onError: (Error) -> Void

    init(onError: @escaping (Error) -> Void) {
        self.onError = onError
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        onError(error)
        context.close(promise: nil)
    }
}

private final class SSHShellChannelHandler: ChannelInboundHandler {
    typealias InboundIn = SSHChannelData

    private let connectionId: UUID
    private let serverId: UUID
    private let term: String
    private let environment: [String: String]
    private let initialWindowSize: (cols: Int, rows: Int)

    init(
        connectionId: UUID,
        serverId: UUID,
        term: String,
        environment: [String: String],
        initialWindowSize: (cols: Int, rows: Int)
    ) {
        self.connectionId = connectionId
        self.serverId = serverId
        self.term = term
        self.environment = environment
        self.initialWindowSize = initialWindowSize
    }

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        print("[SSH-Shell] Channel active, requesting PTY (term=\(term), cols=\(initialWindowSize.cols), rows=\(initialWindowSize.rows))")
        
        // 设置标准终端模式，避免光标和换行异常
        let terminalModes = SSHTerminalModes([
            .TTY_OP_ISPEED: 38400,
            .TTY_OP_OSPEED: 38400,
            .ICRNL: 1,      // 输入: CR → NL (让回车键正常工作)
            .ONLCR: 1,      // 输出: NL → CR+NL (换行时回到行首)
            .ECHO: 1,       // 回显输入
            .ICANON: 1,     // 规范模式(行缓冲)
            .ISIG: 1,       // 启用信号字符(Ctrl+C 等)
            .ECHOE: 1,      // 退格时擦除字符
            .ECHOK: 1,      // 换行时回显
            .OPOST: 1,      // 启用输出处理
        ])
        
        let pty = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: false,
            term: term,
            terminalCharacterWidth: initialWindowSize.cols,
            terminalRowHeight: initialWindowSize.rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: terminalModes
        )
        context.triggerUserOutboundEvent(pty, promise: nil)

        for (name, value) in environment {
            print("[SSH-Shell] Setting env: \(name)=\(value)")
            let env = SSHChannelRequestEvent.EnvironmentRequest(wantReply: false, name: name, value: value)
            context.triggerUserOutboundEvent(env, promise: nil)
        }

        print("[SSH-Shell] Requesting shell")
        context.triggerUserOutboundEvent(SSHChannelRequestEvent.ShellRequest(wantReply: false), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let payload = unwrapInboundIn(data)

        guard case .byteBuffer(var buffer) = payload.data else {
            return
        }

        guard let bytes = buffer.readBytes(length: buffer.readableBytes), !bytes.isEmpty else {
            return
        }

        print("[SSH-Shell] Received \(bytes.count) bytes")
        let chunkSize = 1024
        var next = 0
        while next < bytes.count {
            let end = min(next + chunkSize, bytes.count)
            let chunk = bytes[next..<end]
            let data = Data(chunk)
            DispatchQueue.main.async {
                ConnectionManager.shared.receiveData(serverId: self.serverId, data: data)
            }
            next = end
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let status = event as? SSHChannelRequestEvent.ExitStatus {
            print("[SSH-Shell] Exit status: \(status.exitStatus)")
            DispatchQueue.main.async {
                ConnectionManager.shared.receiveText(serverId: self.serverId, text: "\n[SSH] Session exited with status \(status.exitStatus)\n")
            }
        } else if let signal = event as? SSHChannelRequestEvent.ExitSignal {
            print("[SSH-Shell] Exit signal: \(signal.signalName)")
            DispatchQueue.main.async {
                ConnectionManager.shared.receiveText(serverId: self.serverId, text: "\n[SSH] Session closed: \(signal.signalName)\n")
            }
        } else {
            print("[SSH-Shell] Unhandled event: \(type(of: event))")
            context.fireUserInboundEventTriggered(event)
        }
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        print("[SSH-Shell] Channel became inactive")
        DispatchQueue.main.async {
            ConnectionManager.shared.didDisconnect(serverId: self.serverId, connectionId: self.connectionId)
        }
        context.fireChannelInactive()
    }
}

// MARK: - SSHConnection (公开给 ConnectionManager 使用)

public final class SSHConnection {
    let connectionId = UUID()
    private let serverId: UUID
    private let host: String
    private let port: Int
    private let username: String
    private let password: String
    private let startupScript: String?
    private let term: String
    private let environment: [String: String]
    private let initialWindowSize: (cols: Int, rows: Int)
    private var group: EventLoopGroup?
    private var channel: Channel?
    private var sessionChannel: Channel?
    private var isDisconnecting = false

    init(
        serverId: UUID,
        host: String,
        port: Int,
        username: String,
        password: String,
        startupScript: String?,
        term: String,
        environment: [String: String],
        initialWindowSize: (cols: Int, rows: Int)
    ) {
        self.serverId = serverId
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.startupScript = startupScript
        self.term = term
        self.environment = environment
        self.initialWindowSize = initialWindowSize
    }

    func connect() {
        print("[SSH-Connection] Starting connection to \(host):\(port) as \(username)")
        ConnectionManager.shared.connect(serverId: serverId, connectionId: connectionId)
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group

        let serverAuthDelegate = AcceptAllHostKeysDelegate()
        let userAuthDelegate = SimplePasswordDelegate(username: username, password: password)

        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { [weak self] channel in
                channel.eventLoop.makeCompletedFuture {
                    guard let self else { return }
                    print("[SSH-Connection] Channel initialized, setting up SSH handler")
                    let sshHandler = NIOSSHHandler(
                        role: .client(
                            .init(
                                userAuthDelegate: userAuthDelegate,
                                serverAuthDelegate: serverAuthDelegate
                            )
                        ),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                    try channel.pipeline.syncOperations.addHandler(sshHandler)
                    try channel.pipeline.syncOperations.addHandler(
                        SSHErrorHandler { [weak self] error in
                            print("[SSH-Connection] Channel error: \(error)")
                            self?.handleError(error)
                        }
                    )
                }
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

        bootstrap.connect(host: host, port: port).whenComplete { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("[SSH-Connection] TCP connection failed: \(error)")
                self.reportError(error)
                self.shutdownGroup()
            case .success(let channel):
                print("[SSH-Connection] TCP connected successfully, local: \(channel.localAddress?.description ?? "unknown"), remote: \(channel.remoteAddress?.description ?? "unknown")")
                self.channel = channel
                self.createSessionChannel(on: channel)
            }
        }
    }

    func send(_ data: Data) {
        guard let sessionChannel else {
            print("[SSH-Connection] Cannot send data: no session channel")
            return
        }
        print("[SSH-Connection] Sending \(data.count) bytes")
        sessionChannel.eventLoop.execute {
            var buffer = sessionChannel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            let payload = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
            sessionChannel.writeAndFlush(payload, promise: nil)
        }
    }

    func resize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0, let sessionChannel else {
            print("[SSH-Connection] Cannot resize: cols=\(cols), rows=\(rows), hasChannel=\(sessionChannel != nil)")
            return
        }
        print("[SSH-Connection] Resizing to \(cols)x\(rows)")
        sessionChannel.eventLoop.execute {
            let event = SSHChannelRequestEvent.WindowChangeRequest(
                terminalCharacterWidth: cols,
                terminalRowHeight: rows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0
            )
            sessionChannel.triggerUserOutboundEvent(event, promise: nil)
        }
    }

    func disconnect() {
        print("[SSH-Connection] Disconnecting...")
        isDisconnecting = true
        if let channel, let group {
            channel.closeFuture.whenComplete { [weak self] _ in
                print("[SSH-Connection] Channel closed")
                self?.shutdownGroup()
            }
            channel.close(promise: nil)
        } else {
            shutdownGroup()
        }
    }

    private func createSessionChannel(on channel: Channel) {
        print("[SSH-Connection] Creating SSH session channel...")
        channel.pipeline.handler(type: NIOSSHHandler.self).whenComplete { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                print("[SSH-Connection] Failed to get SSH handler: \(error)")
                self.reportError(error)
            case .success(let sshHandler):
                print("[SSH-Connection] Got SSH handler, creating session channel...")
                let promise = channel.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise, channelType: .session) { [weak self] childChannel, channelType in
                    guard let self else {
                        return channel.eventLoop.makeFailedFuture(SSHClientError.invalidChannelType)
                    }

                    guard channelType == .session else {
                        print("[SSH-Connection] Invalid channel type: \(channelType)")
                        return channel.eventLoop.makeFailedFuture(SSHClientError.invalidChannelType)
                    }

                    print("[SSH-Connection] Configuring shell channel handler...")
                    return childChannel.eventLoop.makeCompletedFuture {
                        let handler = SSHShellChannelHandler(
                            connectionId: self.connectionId,
                            serverId: self.serverId,
                            term: self.term,
                            environment: self.environment,
                            initialWindowSize: self.initialWindowSize
                        )
                        let sync = childChannel.pipeline.syncOperations
                        try sync.addHandler(handler)
                        try sync.addHandler(
                            SSHErrorHandler { [weak self] error in
                                print("[SSH-Connection] Shell channel error: \(error)")
                                self?.handleError(error)
                            }
                        )
                    }
                }

                promise.futureResult.whenComplete { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .failure(let error):
                        print("[SSH-Connection] Session channel creation failed: \(error)")
                        self.reportError(error)
                    case .success(let childChannel):
                        print("[SSH-Connection] Session channel created successfully")
                        self.isDisconnecting = false
                        ConnectionManager.shared.didConnect(serverId: self.serverId, connectionId: self.connectionId)
                        ConnectionManager.shared.storeConnection(self, for: self.serverId)
                        self.sessionChannel = childChannel
                        self.sendStartupScriptIfNeeded()
                        // resize 将在 TerminalHostViewController.viewDidLayoutSubviews 中触发
                    }
                }
            }
        }
    }

    private func sendStartupScriptIfNeeded() {
        guard let startupScript else { return }
        send(Data(startupScript.utf8))
    }

    private func handleError(_ error: Error) {
        guard shouldReport(error: error) else { return }
        print("[SSH-Connection] ERROR: \(error)")
        ConnectionManager.shared.receiveText(serverId: serverId, text: "[ERROR] \(error)\n")
    }

    private func reportError(_ error: Error) {
        guard shouldReport(error: error) else { return }
        ConnectionManager.shared.didError(
            serverId: serverId,
            connectionId: connectionId,
            error: error.localizedDescription
        )
        handleError(error)
    }

    private func shouldReport(error: Error) -> Bool {
        if isDisconnecting {
            return false
        }
        let message = String(describing: error)
        if message.contains("tcpShutdown") || message.contains("already closed") {
            return false
        }
        return true
    }

    private func shutdownGroup() {
        if let group = group {
            print("[SSH-Connection] Shutting down event loop group")
            self.group = nil
            group.shutdownGracefully { _ in }
        }
    }
}

extension SSHConnection: ManagedConnection {}

// MARK: - SshTerminalView

public class SshTerminalView: TerminalView, TerminalViewDelegate {
    private var sshConnection: SSHConnection?
    private var configuredInfo: SSHConnectionInfo?
    
    public override init (frame: CGRect)
    {
        super.init (frame: frame)
        terminalDelegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("[SshTerminalView] Deinitializing, unregistering from ConnectionManager")
        if configuredInfo != nil {
            ConnectionManager.shared.unregisterTerminalView(self)
        }
    }

    func configure(connectionInfo: SSHConnectionInfo) {
        print("[SshTerminalView] Configuring with host: \(connectionInfo.host):\(connectionInfo.port), user: \(connectionInfo.username)")

        // 如果配置信息相同，只是重新注册视图
        if configuredInfo == connectionInfo {
            print("[SshTerminalView] Same connection info, re-registering")
            ConnectionManager.shared.registerTerminalView(self, for: connectionInfo.serverId)
            return
        }

        resetTerminalState()
        configuredInfo = connectionInfo

        // 检查是否已有活跃连接
        if let existing = ConnectionManager.shared.getConnection(for: connectionInfo.serverId) {
            print("[SshTerminalView] Reusing existing connection")
            sshConnection = existing
            ConnectionManager.shared.registerTerminalView(self, for: connectionInfo.serverId)
            // 发送 resize 以适应新视图的尺寸
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let terminal = self.getTerminal()
                let cols = terminal.cols > 0 ? terminal.cols : 80
                let rows = terminal.rows > 0 ? terminal.rows : 24
                existing.resize(cols: cols, rows: rows)
            }
        } else {
            print("[SshTerminalView] Creating new connection")
            startConnection(connectionInfo: connectionInfo)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.becomeFirstResponder()
        }
    }

    private func startConnection(connectionInfo: SSHConnectionInfo) {
        let terminal = getTerminal()
        let cols = terminal.cols > 0 ? terminal.cols : 80
        let rows = terminal.rows > 0 ? terminal.rows : 24
        print("[SshTerminalView] Starting connection with terminal size: \(cols)x\(rows)")

        let connection = SSHConnection(
            serverId: connectionInfo.serverId,
            host: connectionInfo.host,
            port: connectionInfo.port,
            username: connectionInfo.username,
            password: connectionInfo.password,
            startupScript: connectionInfo.preparedStartupScript,
            term: connectionInfo.term,
            environment: connectionInfo.environment,
            initialWindowSize: (cols: cols, rows: rows)
        )
        sshConnection = connection
        ConnectionManager.shared.storeConnection(connection, for: connectionInfo.serverId)
        ConnectionManager.shared.registerTerminalView(self, for: connectionInfo.serverId)
        connection.connect()
    }

    private func resetTerminalState() {
        clearSelection()
        getTerminal().resetToInitialState()
    }

    // TerminalViewDelegate conformance
    public func scrolled(source: TerminalView, position: Double) {
        //
    }
    
    public func setTerminalTitle(source: TerminalView, title: String) {
        //
    }
    
    public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        sshConnection?.resize(cols: newCols, rows: newRows)
    }
    
    /// 由外部（如 TerminalHostViewController）在 view layout 完成后调用，
    /// 确保 SSH 连接使用正确的终端尺寸
    func updateConnectionSize() {
        let terminal = getTerminal()
        let cols = terminal.cols > 0 ? terminal.cols : 80
        let rows = terminal.rows > 0 ? terminal.rows : 24
        print("[SshTerminalView] updateConnectionSize: \(cols)x\(rows)")
        sshConnection?.resize(cols: cols, rows: rows)
    }
    
    public func send(source: TerminalView, data: ArraySlice<UInt8>) {
        sshConnection?.send(Data(data))
    }
    
    public func clipboardCopy(source: TerminalView, content: Data) {
        if let str = String (bytes: content, encoding: .utf8) {
            UIPasteboard.general.string = str
        }
    }
    
    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        
    }

    public func requestOpenLink (source: TerminalView, link: String, params: [String:String])
    {
        if let url = URL(string: link) {
            UIApplication.shared.open (url)
        }
    }
    
    public func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {
        // nothing
    }
    

}
