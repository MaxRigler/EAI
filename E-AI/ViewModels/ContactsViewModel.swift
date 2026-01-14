// ContactsViewModel.swift
// Contacts list management

import Foundation

enum ContactFilterType: String, CaseIterable {
    case all = "All"
    case companies = "Companies"
    case people = "People"
}

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var contacts: [CRMContact] = []
    @Published var filteredContacts: [CRMContact] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchQuery = ""
    @Published var filterType: ContactFilterType = .all
    
    private let repository = ContactRepository()
    
    func loadContacts() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let allContacts = try await repository.fetchAllContacts()
                self.contacts = allContacts
                self.applyFilters()
                print("Loaded \(allContacts.count) contacts")
            } catch {
                self.error = error
                print("Failed to load contacts: \(error)")
            }
            self.isLoading = false
        }
    }
    
    func setFilter(_ type: ContactFilterType) {
        filterType = type
        applyFilters()
    }
    
    func search(query: String) {
        searchQuery = query
        applyFilters()
    }
    
    private func applyFilters() {
        var result = contacts
        
        // Apply type filter
        switch filterType {
        case .all:
            break // No filtering
        case .companies:
            result = result.filter { $0.isCompany }
        case .people:
            result = result.filter { !$0.isCompany }
        }
        
        // Apply search filter
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.company?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
                ($0.email?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
        
        filteredContacts = result
    }
    
    func createContact(name: String, email: String?, phone: String?, company: String?) {
        Task {
            do {
                let newContact = CRMContact(
                    name: name,
                    email: email,
                    phone: phone,
                    company: company
                )
                var created = try await repository.createContact(newContact)
                
                // Create iOS Contact for iCloud sync
                let contactsManager = ContactsManager.shared
                if contactsManager.authorizationStatus == .authorized {
                    // Parse name into first/last
                    let nameParts = name.components(separatedBy: " ")
                    let firstName = nameParts.first ?? name
                    let lastName = nameParts.dropFirst().joined(separator: " ")
                    
                    do {
                        let appleContact = try await contactsManager.createContact(
                            firstName: firstName,
                            lastName: lastName.isEmpty ? "" : lastName,
                            email: email,
                            phone: phone,
                            company: company
                        )
                        
                        // Link the iOS Contact to the CRM Contact
                        created.appleContactId = appleContact.identifier
                        created = try await repository.updateContact(created)
                        print("ContactsViewModel: Created and linked iOS Contact: \(appleContact.identifier)")
                    } catch {
                        // Log but don't fail - Supabase save succeeded
                        print("ContactsViewModel: Failed to create iOS Contact: \(error)")
                    }
                }
                
                self.contacts.append(created)
                self.applyFilters()
            } catch {
                self.error = error
            }
        }
    }

}

