//
//  SettingsMenuView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import SwiftUI

struct SettingsMenuView: View {
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var settingsManager: SettingsTabManager
    var openSendFeedback: () -> Void
    var isPreview: Bool = false;
    
    init(openSendFeedback: @escaping () -> Void, isPreview: Bool = false) {
        self.isPreview = isPreview
        self.openSendFeedback = openSendFeedback
    }
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsMenuOption(label: "WIDGET_SETTINGS_PREFERENCES_OPTION", onPress: handleOpenPreferences)
                    SettingsMenuOption(label: "WIDGET_SETTINGS_SUPPORT_OPTION", onPress: handleOpenSupport)
                    SettingsMenuOption(label: "WIDGET_SETTINGS_LOGOUT_OPTION", onPress: handleLogout)
                    Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 140, height: 1)
                    .background(Color.Gray10)
                    SettingsMenuOption(label: "WIDGET_SETTINGS_QUIT_OPTION", onPress: handleQuitApp)
                }
                .padding(.vertical, 6).ifAvailable{view in
                    
                    if #available(macOS 12, *) {
                        view.overlay{
                            RoundedRectangle(cornerRadius: 8).stroke(Color.Gray20, lineWidth: 1)
                        }
                    } else {
                        view.overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(Color.Gray20, lineWidth: 1)
                            , alignment: .top)
                    }
                    
                }
                .background(Color.Gray1)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 12.5, x: 0, y: 20)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 8)
                
            }.offset(x: -(isPreview ? 0 : (140 - 32)), y: isPreview ? 0 : (proxy.size.height + 4)).zIndex(10)
            
        }.frame(width: 140)
    }
    
    func handleOpenPreferences() -> Void {
        settingsManager.focusedTab = .General
        Task { await usageManager.updateUsage() }
        NSApp.sendAction(#selector(AppDelegate.openSettingsWindow), to: nil, from: nil)
    }
    
    func handleLogout() -> Void {
        do {
            try authManager.signOut()
        } catch {
            error.reportToSentry()
        }
        
    }
    
    func handleOpenSupport() -> Void {
        URLDictionary.HELP_CENTER.open()
    }
    
    func handleSendFeedback() -> Void {
        self.openSendFeedback()
    }
    
    func handleQuitApp() -> Void {
        NSApp.terminate(self)
    }
    
    
    
}

struct SettingsMenuOption: View {
    public var label: String
    public var onPress: () -> Void
    @State private var isHovering: Bool = false
    
    init(label: String, onPress: @escaping () -> Void) {
        self.label = label
        self.onPress = onPress
    }
    
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            AppText(label)
                .font(.SMRegular)
                .padding(.horizontal, 12)
                .frame(height: 32)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Gray5.opacity(isHovering ? 1: 0))
        .onTapGesture {
            withAnimation{
                onPress()
            }
        }
        .onHover{isHovering in
            self.isHovering = isHovering
        }
    }
}




struct SettingsMenu_Previews: PreviewProvider {
    static var previews: some View {
        SettingsMenuView(openSendFeedback: {}, isPreview: true).frame(height: 200).padding(10)
    }
}
