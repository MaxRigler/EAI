// MainTabView.swift
// Bottom tab navigation with 5 tabs

import SwiftUI

struct MainTabView: View {
    let onCollapse: () -> Void
    
    @ObservedObject private var navState = AppNavigationState.shared
    @State private var showSettings = false
    
    enum Tab: String, CaseIterable {
        case recorder = "Recorder"
        case contacts = "Contacts"
        case chat = "Chat"
        case tasks = "Tasks"
        case daily = "Daily"
        
        var icon: String {
            switch self {
            case .recorder: return "mic.fill"
            case .contacts: return "person.2.fill"
            case .chat: return "bubble.left.and.bubble.right.fill"
            case .tasks: return "checklist"
            case .daily: return "calendar"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with collapse and settings
            topBar
            
            // Main content area
            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom tab bar
            tabBar
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(width: 350, height: 600)
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Collapse button
            Button(action: onCollapse) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Collapse")
            
            Spacer()
            
            Text("E-AI")
                .font(.headline)
            
            Spacer()
            
            // Settings button
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        switch navState.selectedTab {
        case .recorder:
            RecorderView()
        case .contacts:
            ContactsView()
        case .chat:
            ChatView()
        case .tasks:
            TasksView()
        case .daily:
            DailyView()
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
    
    private func tabButton(for tab: Tab) -> some View {
        Button(action: { navState.selectedTab = tab }) {
            VStack(spacing: 4) {
                ZStack {
                    // Special treatment for Chat tab (center, prominent)
                    if tab == .chat {
                        Circle()
                            .fill(navState.selectedTab == tab ? Color.accentColor : Color.accentColor.opacity(0.2))
                            .frame(width: 44, height: 44)
                    }
                    
                    Image(systemName: tab.icon)
                        .font(.system(size: tab == .chat ? 18 : 16))
                        .foregroundColor(tabIconColor(for: tab))
                }
                
                Text(tab.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(navState.selectedTab == tab ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private func tabIconColor(for tab: Tab) -> Color {
        if tab == .chat {
            return navState.selectedTab == tab ? .white : .accentColor
        }
        return navState.selectedTab == tab ? .accentColor : .secondary
    }
}

#Preview {
    MainTabView(onCollapse: {})
        .frame(width: 390, height: 844)
}
