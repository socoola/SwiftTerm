//
//  SettingsView.swift
//  iOSTerminal
//
//  Created by Assistant on 1/20/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsStore.shared
    var showDismissButton: Bool = true
    
    var body: some View {
        Form {
                Section(header: Text("终端外观")) {
                    HStack {
                        Text("字体大小")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(Int(settings.fontSize))pt")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.fontSize, in: 8...24, step: 1) {
                        Text("字体大小")
                    } minimumValueLabel: {
                        Text("8")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("24")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("行间距")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(String(format: "%.1fx", settings.lineSpacing))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settings.lineSpacing, in: 0.8...2.0, step: 0.1) {
                        Text("行间距")
                    } minimumValueLabel: {
                        Text("0.8")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("2.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink(destination: ThemePickerView()) {
                        HStack {
                            Text("主题")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(settings.theme.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: CursorStylePickerView()) {
                        HStack {
                            Text("光标样式")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(settings.cursorStyle.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("连接设置")) {
                    HStack {
                        Text("保活间隔")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(settings.keepAliveInterval)秒")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(settings.keepAliveInterval) },
                        set: { settings.keepAliveInterval = Int($0) }
                    ), in: 5...120, step: 5) {
                        Text("保活间隔")
                    } minimumValueLabel: {
                        Text("5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("120")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("超时时间")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(settings.timeoutSeconds)秒")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(settings.timeoutSeconds) },
                        set: { settings.timeoutSeconds = Int($0) }
                    ), in: 5...60, step: 5) {
                        Text("超时时间")
                    } minimumValueLabel: {
                        Text("5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("60")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/migueldeicaza/SwiftTerm")!) {
                        HStack {
                            Text("SwiftTerm")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if showDismissButton {
                            dismiss()
                        }
                    }) {
                        Text(showDismissButton ? "完成" : "")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .opacity(showDismissButton ? 1 : 0)
                    .disabled(!showDismissButton)
                }
            }
        }
    }

struct ThemePickerView: View {
    @StateObject private var settings = SettingsStore.shared
    
    var body: some View {
        List {
            ForEach(TerminalTheme.allCases) { theme in
                Button(action: {
                    settings.theme = theme
                }) {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(theme.backgroundColor))
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text(theme.displayName)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if settings.theme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                }
            }
        }
        .navigationTitle("主题")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
    }
}

struct CursorStylePickerView: View {
    @StateObject private var settings = SettingsStore.shared
    
    var body: some View {
        List {
            ForEach(AppCursorStyle.allCases) { style in
                Button(action: {
                    settings.cursorStyle = style
                }) {
                    HStack {
                        Text(style.rawValue)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if settings.cursorStyle == style {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                }
            }
        }
        .navigationTitle("光标样式")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
    }
}
