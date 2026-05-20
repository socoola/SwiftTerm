//
//  SSHServer.swift
//  iOSTerminal
//
//  Created by Assistant on 1/20/25.
//

import Foundation

protocol ServerDeleting {
    func delete(_ server: SSHServer)
}

struct SSHServer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var password: String
    var lastConnected: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        password: String,
        lastConnected: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.lastConnected = lastConnected
    }
    
    var displayAddress: String {
        "\(host):\(port)"
    }
    
    var connectionInfo: SSHConnectionInfo {
        SSHConnectionInfo(
            serverId: id,
            host: host,
            port: port,
            username: username,
            password: password
        )
    }
}

class ServerStore: ObservableObject {
    @Published var servers: [SSHServer] = []
    
    private let saveKey = "iosterminal.servers"
    
    init() {
        load()
    }
    
    func add(_ server: SSHServer) {
        servers.append(server)
        save()
    }
    
    func update(_ server: SSHServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server
            save()
        }
    }
    
    func delete(_ server: SSHServer) {
        servers.removeAll { $0.id == server.id }
        save()
    }
    
    func updateLastConnected(_ server: SSHServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].lastConnected = Date()
            save()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([SSHServer].self, from: data) else {
            return
        }
        servers = decoded
    }
}

extension ServerStore: ServerDeleting {}
