//
//  ServerEditView.swift
//  iOSTerminal
//
//  Created by Assistant on 1/20/25.
//

import SwiftUI

struct ServerEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    var server: SSHServer?
    var onSave: (SSHServer) -> Void
    var onDelete: ((SSHServer) -> Void)?
    
    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var password: String
    @State private var startupScript: String
    @State private var showPassword: Bool = false
    
    private var isEditing: Bool { server != nil }
    
    init(
        server: SSHServer? = nil,
        onSave: @escaping (SSHServer) -> Void,
        onDelete: ((SSHServer) -> Void)? = nil
    ) {
        self.server = server
        self.onSave = onSave
        self.onDelete = onDelete
        
        _name = State(initialValue: server?.name ?? "")
        _host = State(initialValue: server?.host ?? "")
        _port = State(initialValue: server.map { String($0.port) } ?? "22")
        _username = State(initialValue: server?.username ?? "")
        _password = State(initialValue: server?.password ?? "")
        _startupScript = State(initialValue: server?.startupScript ?? "")
    }
    
    private var isValid: Bool {
        !name.isEmpty &&
        !host.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty &&
        (Int(port) != nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("服务器信息")) {
                    HStack {
                        Text("名称")
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("例如：我的服务器", text: $name)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 150)
                    }
                    
                    HStack {
                        Text("主机")
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("例如：192.168.1.1", text: $host)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .frame(minWidth: 150)
                    }
                    
                    HStack {
                        Text("端口")
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("22", text: $port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                }
                
                Section(header: Text("认证信息")) {
                    HStack {
                        Text("用户名")
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("例如：root", text: $username)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .frame(minWidth: 150)
                    }
                    
                    HStack {
                        Text("密码")
                            .foregroundColor(.primary)
                        Spacer()
                        HStack(spacing: 8) {
                            if showPassword {
                                TextField("输入密码", text: $password)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                SecureField("输入密码", text: $password)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(minWidth: 150)
                    }
                }

                Section(
                    header: Text("启动脚本"),
                    footer: Text("连接成功后会自动执行，适合放初始化命令或进入工作目录。")
                ) {
                    TextEditor(text: $startupScript)
                        .frame(minHeight: 120)
                        .font(.system(.body, design: .monospaced))
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            guard let server else { return }
                            onDelete?(server)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除服务器")
                                Spacer()
                            }
                        }
                        .disabled(onDelete == nil)
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑服务器" : "添加服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!isValid)
                    .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    private func save() {
        guard let portInt = Int(port) else { return }
        
        let newServer = SSHServer(
            id: server?.id ?? UUID(),
            name: name,
            host: host,
            port: portInt,
            username: username,
            password: password,
            startupScript: normalizedStartupScript,
            lastConnected: server?.lastConnected
        )
        
        onSave(newServer)
        dismiss()
    }

    private var normalizedStartupScript: String? {
        let trimmed = startupScript.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
