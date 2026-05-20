//
//  ServerListView.swift
//  iOSTerminal
//
//  Created by Assistant on 1/20/25.
//

import SwiftUI

struct ServerListView: View {
    @EnvironmentObject private var store: ServerStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedServer: SSHServer?
    @State private var editingServer: SSHServer?
    @State private var showAddSheet = false
    @State private var isManualDisconnect = false
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    var body: some View {
        ZStack {
            background
            
            if store.servers.isEmpty {
                emptyStateView
            } else {
                serverList
            }
        }
        .navigationTitle("服务器")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .sheet(item: $selectedServer, onDismiss: {
            if !isManualDisconnect {
                // 下滑关闭：保持连接
                print("[ServerList] Sheet dismissed (swipe down), keeping connection")
            }
            isManualDisconnect = false
        }) { server in
            TerminalSessionView(server: server, onDisconnect: {
                isManualDisconnect = true
                ConnectionManager.shared.disconnect(serverId: server.id)
                store.updateLastConnected(server)
                selectedServer = nil
            })
        }
        .sheet(item: $editingServer) { server in
            ServerEditView(
                server: server,
                onSave: { updated in
                    store.update(updated)
                    editingServer = nil
                },
                onDelete: { deleted in
                    Self.deleteServer(
                        deleted,
                        store: store,
                        connectionManager: ConnectionManager.shared
                    )
                    editingServer = nil
                }
            )
        }
        .sheet(isPresented: $showAddSheet) {
            ServerEditView { server in
                store.add(server)
                showAddSheet = false
            }
        }
    }
    
    private var serverList: some View {
        List {
            ForEach(store.servers) { server in
                ServerRow(server: server, isIPad: isIPad)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedServer = server
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Self.deleteServer(
                                server,
                                store: store,
                                connectionManager: ConnectionManager.shared
                            )
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            editingServer = server
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        .tint(Color(red: 0.17, green: 0.47, blue: 0.50))
                    }
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "server.rack")
                .font(.system(size: isIPad ? 80 : 60, weight: .light))
                .foregroundColor(Color(red: 0.75, green: 0.79, blue: 0.82))
            
            Text("没有服务器")
                .font(.system(size: isIPad ? 24 : 20, weight: .semibold))
                .foregroundColor(Color(red: 0.45, green: 0.50, blue: 0.54))
            
            Text("点击右上角 + 添加服务器")
                .font(.system(size: isIPad ? 18 : 15))
                .foregroundColor(Color(red: 0.60, green: 0.64, blue: 0.67))
            
            Spacer()
        }
        .padding()
    }
    
    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            store.delete(store.servers[index])
        }
    }
    
    private var background: some View {
        Color(red: 0.97, green: 0.97, blue: 0.95)
            .ignoresSafeArea()
    }
    
    static func deleteServer(
        _ server: SSHServer,
        store: any ServerDeleting,
        connectionManager: any ConnectionDisconnecting
    ) {
        connectionManager.disconnect(serverId: server.id)
        store.delete(server)
    }
}

struct ServerRow: View {
    let server: SSHServer
    let isIPad: Bool
    @StateObject private var connectionManager = ConnectionManager.shared
    
    var body: some View {
        HStack(spacing: isIPad ? 20 : 16) {
            // 服务器图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.17, green: 0.47, blue: 0.50),
                                Color(red: 0.11, green: 0.34, blue: 0.37)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isIPad ? 56 : 50, height: isIPad ? 56 : 50)
                
                Image(systemName: "server.rack")
                    .font(.system(size: isIPad ? 26 : 22))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: isIPad ? 6 : 4) {
                HStack(spacing: 8) {
                    Text(server.name)
                        .font(.system(size: isIPad ? 19 : 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))
                    
                    ConnectionStatusIndicator(status: connectionManager.status(for: server.id))
                }
                
                HStack(spacing: 4) {
                    Text(server.username)
                        .font(.system(size: isIPad ? 15 : 14, weight: .medium))
                        .foregroundColor(Color(red: 0.45, green: 0.50, blue: 0.54))
                    
                    Text("•")
                        .font(.system(size: isIPad ? 15 : 14))
                        .foregroundColor(Color(red: 0.70, green: 0.74, blue: 0.77))
                    
                    Text(server.displayAddress)
                        .font(.system(size: isIPad ? 15 : 14, weight: .medium))
                        .foregroundColor(Color(red: 0.45, green: 0.50, blue: 0.54))
                }
                
                if let lastConnected = server.lastConnected {
                    Text("上次连接: \(lastConnected.relativeTime)")
                        .font(.system(size: isIPad ? 13 : 12))
                        .foregroundColor(Color(red: 0.60, green: 0.64, blue: 0.67))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                .foregroundColor(Color(red: 0.75, green: 0.79, blue: 0.82))
        }
        .padding(.vertical, isIPad ? 12 : 8)
        .padding(.horizontal, isIPad ? 8 : 4)
    }
}

struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .disconnected:
            return Color.gray
        case .connecting:
            return Color.orange
        case .connected:
            return Color.green
        case .error:
            return Color.red
        }
    }
    
    private var statusText: String {
        switch status {
        case .disconnected:
            return ""
        case .connecting:
            return "连接中"
        case .connected:
            return "已连接"
        case .error:
            return "失败"
        }
    }
}

struct TerminalSessionView: View {
    let server: SSHServer
    let onDisconnect: () -> Void
    @StateObject private var connectionManager = ConnectionManager.shared
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部状态栏
                ConnectionStatusBar(
                    serverName: server.name,
                    status: connectionManager.status(for: server.id),
                    onDisconnect: onDisconnect
                )
                
                // 终端视图
                TerminalHostRepresentable(connectionInfo: server.connectionInfo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct ConnectionStatusBar: View {
    let serverName: String
    let status: ConnectionStatus
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态指示器
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            Text(serverName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onDisconnect) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                    Text("断开")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
    }
    
    private var statusColor: Color {
        switch status {
        case .disconnected:
            return Color.gray
        case .connecting:
            return Color.orange
        case .connected:
            return Color.green
        case .error:
            return Color.red
        }
    }
    
    private var statusText: String {
        switch status {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中..."
        case .connected:
            return "已连接"
        case .error(let msg):
            return "错误: \(msg)"
        }
    }
}

// 时间格式化扩展
extension Date {
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
