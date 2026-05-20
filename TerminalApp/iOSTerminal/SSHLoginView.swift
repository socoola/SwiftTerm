//
//  SSHLoginView.swift
//  iOSTerminal
//
//  Created by Codex on 1/15/25.
//

import SwiftUI

struct SSHLoginView: View {
    @State private var host: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var connectionInfo: SSHConnectionInfo?
    @State private var animate = false

    var body: some View {
        ZStack {
            background

            if let info = connectionInfo {
                TerminalShellView(connectionInfo: info) {
                    connectionInfo = Self.disconnectSession(info, using: ConnectionManager.shared)
                }
            } else {
                loginCard
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) {
                animate = true
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.95, blue: 0.92),
                    Color(red: 0.86, green: 0.91, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.23, green: 0.51, blue: 0.55, opacity: 0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: animate ? 140 : 200, y: animate ? -240 : -280)

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.79, blue: 0.55, opacity: 0.4),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 280, height: 220)
                .rotationEffect(.degrees(-12))
                .offset(x: animate ? -130 : -160, y: animate ? 220 : 260)
        }
    }

    private var loginCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("SSH Terminal")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))

                Text("Connect to your server")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.36, green: 0.42, blue: 0.46))
            }

            VStack(spacing: 12) {
                TextField("Host (e.g., 192.168.1.1)", text: $host)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                TextField("Username", text: $username)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                SecureField("Password", text: $password)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.12, green: 0.15, blue: 0.18))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                    )
            }

            Spacer()

            Button(action: connect) {
                HStack(spacing: 12) {
                    Text("Connect")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.17, green: 0.47, blue: 0.50),
                                    Color(red: 0.11, green: 0.34, blue: 0.37)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(host.isEmpty || username.isEmpty || password.isEmpty)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 12)
        )
        .padding(.horizontal, 24)
    }

    private func connect() {
        print("[SSH-Login] Connecting to \(host):22 as \(username)")
        connectionInfo = SSHConnectionInfo(
            host: host,
            username: username,
            password: password
        )
    }
    
    static func disconnectSession(
        _ info: SSHConnectionInfo?,
        using connectionManager: any ConnectionDisconnecting
    ) -> SSHConnectionInfo? {
        guard let info else { return nil }
        connectionManager.disconnect(serverId: info.serverId)
        return nil
    }
}

private struct TerminalShellView: View {
    let connectionInfo: SSHConnectionInfo
    let onDisconnect: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TerminalHostRepresentable(connectionInfo: connectionInfo)

            Button(action: onDisconnect) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                    Text("Disconnect")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
    }
}

struct TerminalHostRepresentable: UIViewControllerRepresentable {
    let connectionInfo: SSHConnectionInfo

    func makeUIViewController(context: Context) -> TerminalHostViewController {
        let controller = TerminalHostViewController()
        controller.updateConnectionInfo(connectionInfo)
        return controller
    }

    func updateUIViewController(_ uiViewController: TerminalHostViewController, context: Context) {
        uiViewController.updateConnectionInfo(connectionInfo)
    }
}
