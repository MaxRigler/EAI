// AppNavigationState.swift
// Shared navigation state for cross-tab navigation

import Foundation
import SwiftUI

/// Shared state to enable navigation between tabs and passing data
class AppNavigationState: ObservableObject {
    static let shared = AppNavigationState()
    
    /// The currently selected tab
    @Published var selectedTab: MainTabView.Tab = .daily
    
    /// Contact to show in the Contacts tab (set from other tabs)
    @Published var selectedContact: CRMContact?
    
    /// Navigate to a contact's detail page in the Contacts tab
    func navigateToContact(_ contact: CRMContact) {
        selectedContact = contact
        selectedTab = .contacts
    }
    
    /// Clear the selected contact (when going back to contact list)
    func clearSelectedContact() {
        selectedContact = nil
    }
    
    private init() {}
}
