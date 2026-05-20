//
//  SettingsStore.swift
//  iOSTerminal
//
//  Created by Assistant on 1/20/25.
//

import Foundation
import UIKit
import SwiftTerm

enum TerminalTheme: String, CaseIterable, Identifiable, Codable {
    case dark = "深色"
    case light = "浅色"
    case monokai = "Monokai"
    case solarizedDark = "Solarized Dark"
    case solarizedLight = "Solarized Light"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dark: return "深色"
        case .light: return "浅色"
        case .monokai: return "Monokai"
        case .solarizedDark: return "Solarized Dark"
        case .solarizedLight: return "Solarized Light"
        }
    }
    
    var backgroundColor: UIColor {
        switch self {
        case .dark: return .black
        case .light: return UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        case .monokai: return UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1)
        case .solarizedDark: return UIColor(red: 0.00, green: 0.17, blue: 0.21, alpha: 1)
        case .solarizedLight: return UIColor(red: 0.99, green: 0.96, blue: 0.89, alpha: 1)
        }
    }
    
    var foregroundColor: UIColor {
        switch self {
        case .dark: return .white
        case .light: return .black
        case .monokai: return UIColor(red: 0.87, green: 0.87, blue: 0.87, alpha: 1)
        case .solarizedDark: return UIColor(red: 0.51, green: 0.58, blue: 0.59, alpha: 1)
        case .solarizedLight: return UIColor(red: 0.40, green: 0.48, blue: 0.51, alpha: 1)
        }
    }
    
    var ansiColors: [Color] {
        switch self {
        case .dark:
            return []
        case .light:
            return []
        case .monokai:
            return [
                Color(red: 39 * 257, green: 40 * 257, blue: 34 * 257),
                Color(red: 249 * 257, green: 38 * 257, blue: 114 * 257),
                Color(red: 166 * 257, green: 226 * 257, blue: 46 * 257),
                Color(red: 244 * 257, green: 208 * 257, blue: 63 * 257),
                Color(red: 102 * 257, green: 217 * 257, blue: 239 * 257),
                Color(red: 174 * 257, green: 129 * 257, blue: 255 * 257),
                Color(red: 161 * 257, green: 239 * 257, blue: 228 * 257),
                Color(red: 248 * 257, green: 248 * 257, blue: 242 * 257),
                Color(red: 117 * 257, green: 113 * 257, blue: 94 * 257),
                Color(red: 249 * 257, green: 38 * 257, blue: 114 * 257),
                Color(red: 166 * 257, green: 226 * 257, blue: 46 * 257),
                Color(red: 244 * 257, green: 208 * 257, blue: 63 * 257),
                Color(red: 102 * 257, green: 217 * 257, blue: 239 * 257),
                Color(red: 174 * 257, green: 129 * 257, blue: 255 * 257),
                Color(red: 161 * 257, green: 239 * 257, blue: 228 * 257),
                Color(red: 248 * 257, green: 248 * 257, blue: 248 * 257)
            ]
        case .solarizedDark:
            return [
                Color(red: 7 * 257, green: 54 * 257, blue: 66 * 257),
                Color(red: 220 * 257, green: 50 * 257, blue: 47 * 257),
                Color(red: 133 * 257, green: 153 * 257, blue: 0 * 257),
                Color(red: 181 * 257, green: 137 * 257, blue: 0 * 257),
                Color(red: 38 * 257, green: 139 * 257, blue: 210 * 257),
                Color(red: 211 * 257, green: 54 * 257, blue: 130 * 257),
                Color(red: 42 * 257, green: 161 * 257, blue: 152 * 257),
                Color(red: 238 * 257, green: 232 * 257, blue: 213 * 257),
                Color(red: 0 * 257, green: 43 * 257, blue: 54 * 257),
                Color(red: 203 * 257, green: 75 * 257, blue: 22 * 257),
                Color(red: 88 * 257, green: 110 * 257, blue: 117 * 257),
                Color(red: 101 * 257, green: 123 * 257, blue: 131 * 257),
                Color(red: 131 * 257, green: 148 * 257, blue: 150 * 257),
                Color(red: 108 * 257, green: 113 * 257, blue: 196 * 257),
                Color(red: 147 * 257, green: 161 * 257, blue: 161 * 257),
                Color(red: 253 * 257, green: 246 * 257, blue: 227 * 257)
            ]
        case .solarizedLight:
            return [
                Color(red: 238 * 257, green: 232 * 257, blue: 213 * 257),
                Color(red: 220 * 257, green: 50 * 257, blue: 47 * 257),
                Color(red: 133 * 257, green: 153 * 257, blue: 0 * 257),
                Color(red: 181 * 257, green: 137 * 257, blue: 0 * 257),
                Color(red: 38 * 257, green: 139 * 257, blue: 210 * 257),
                Color(red: 211 * 257, green: 54 * 257, blue: 130 * 257),
                Color(red: 42 * 257, green: 161 * 257, blue: 152 * 257),
                Color(red: 101 * 257, green: 123 * 257, blue: 131 * 257),
                Color(red: 88 * 257, green: 110 * 257, blue: 117 * 257),
                Color(red: 203 * 257, green: 75 * 257, blue: 22 * 257),
                Color(red: 88 * 257, green: 110 * 257, blue: 117 * 257),
                Color(red: 101 * 257, green: 123 * 257, blue: 131 * 257),
                Color(red: 131 * 257, green: 148 * 257, blue: 150 * 257),
                Color(red: 108 * 257, green: 113 * 257, blue: 196 * 257),
                Color(red: 147 * 257, green: 161 * 257, blue: 161 * 257),
                Color(red: 7 * 257, green: 54 * 257, blue: 66 * 257)
            ]
        }
    }
}

enum AppCursorStyle: String, CaseIterable, Identifiable, Codable {
    case block = "块状"
    case bar = "竖线"
    case underline = "下划线"
    
    var id: String { rawValue }
}

class SettingsStore: ObservableObject {
    @Published var fontSize: CGFloat {
        didSet { save() }
    }
    @Published var theme: TerminalTheme {
        didSet { save() }
    }
    @Published var cursorStyle: AppCursorStyle {
        didSet { save() }
    }
    @Published var lineSpacing: CGFloat {
        didSet { save() }
    }
    @Published var keepAliveInterval: Int {
        didSet { save() }
    }
    @Published var timeoutSeconds: Int {
        didSet { save() }
    }
    
    static let shared = SettingsStore()
    
    private let saveKey = "iosterminal.settings"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) {
            self.fontSize = decoded.fontSize
            self.theme = decoded.theme
            self.cursorStyle = decoded.cursorStyle
            self.lineSpacing = decoded.lineSpacing
            self.keepAliveInterval = decoded.keepAliveInterval
            self.timeoutSeconds = decoded.timeoutSeconds
        } else {
            self.fontSize = 14
            self.theme = .dark
            self.cursorStyle = .block
            self.lineSpacing = 1.0
            self.keepAliveInterval = 30
            self.timeoutSeconds = 10
        }
    }
    
    func apply(to terminalView: SshTerminalView) {
        let newFont = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        terminalView.font = newFont
        terminalView.nativeBackgroundColor = theme.backgroundColor
        terminalView.nativeForegroundColor = theme.foregroundColor
        terminalView.lineSpacing = lineSpacing
        
        let colors = theme.ansiColors
        if colors.count == 16 {
            terminalView.installColors(colors)
        }
        
        switch cursorStyle {
        case .block:
            terminalView.getTerminal().setCursorStyle(.steadyBlock)
        case .bar:
            terminalView.getTerminal().setCursorStyle(.steadyBar)
        case .underline:
            terminalView.getTerminal().setCursorStyle(.steadyUnderline)
        }
    }
    
    private func save() {
        let data = SettingsData(
            fontSize: fontSize,
            theme: theme,
            cursorStyle: cursorStyle,
            lineSpacing: lineSpacing,
            keepAliveInterval: keepAliveInterval,
            timeoutSeconds: timeoutSeconds
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
}

private struct SettingsData: Codable {
    var fontSize: CGFloat
    var theme: TerminalTheme
    var cursorStyle: AppCursorStyle
    var lineSpacing: CGFloat
    var keepAliveInterval: Int
    var timeoutSeconds: Int
}
