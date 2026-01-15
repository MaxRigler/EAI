// ContactsView.swift
// List of all Business Contacts

import SwiftUI

struct ContactsView: View {
    @StateObject private var viewModel = ContactsViewModel()
    @ObservedObject private var navState = AppNavigationState.shared
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    @State private var showCreateContact = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Filter picker
                filterPicker
                
                // Search bar
                searchBar
                
                // Contact list
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredContacts.isEmpty {
                    emptyState
                } else {
                    contactList
                }
            }
            .navigationTitle("Contacts")
            .navigationDestination(for: CRMContact.self) { contact in
                ContactDetailView(contact: contact)
            }
            .onAppear {
                viewModel.loadContacts()
                // Check if we should navigate to a specific contact (from another tab)
                if let contact = navState.selectedContact {
                    // Small delay to ensure NavigationStack is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigationPath.append(contact)
                        navState.clearSelectedContact()
                    }
                }
            }
            .onChange(of: navigationPath) { newPath in
                // Reload contacts when navigating back to the list (path becomes empty)
                if newPath.isEmpty {
                    viewModel.loadContacts()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .contactsDidChange)) { _ in
                // Reload contacts when a contact is deleted or changed
                print("ContactsView: Received contactsDidChange notification, reloading contacts...")
                viewModel.loadContacts()
            }
            .onChange(of: navState.selectedContact) { newContact in
                // When a contact is selected from another tab while already in Contacts tab
                if let contact = newContact {
                    navigationPath.append(contact)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navState.clearSelectedContact()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateContact = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateContact) {
                CreateContactSheet(onSave: { newContact in
                    viewModel.loadContacts() // Refresh list
                    navigationPath.append(newContact) // Navigate to new contact
                })
            }
        }
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        HStack(spacing: 12) {
            Picker("Filter", selection: Binding(
                get: { viewModel.filterType },
                set: { viewModel.setFilter($0) }
            )) {
                ForEach(ContactFilterType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // Add Contact button
            Button(action: { showCreateContact = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Add Contact")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search contacts...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { newValue in
                    viewModel.search(query: newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: { 
                    searchText = ""
                    viewModel.search(query: "")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - Contact List
    
    private var contactList: some View {
        List(viewModel.filteredContacts) { contact in
            NavigationLink(destination: ContactDetailView(contact: contact)) {
                ContactRow(contact: contact, labels: viewModel.labels(for: contact.id))
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Contacts Yet")
                .font(.headline)
            
            Text("Contacts will appear here after you associate them with recordings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: CRMContact
    var labels: [ContactLabel] = []
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with company indicator
            ZStack {
                Circle()
                    .fill(contact.isCompany ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                if contact.isCompany {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.orange)
                } else {
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body)
                
                if let company = contact.company, !contact.isCompany {
                    HStack(spacing: 4) {
                        Image(systemName: "building.2")
                            .font(.caption2)
                        Text("@ \(company)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else if contact.isCompany {
                    Text("Company")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                // Labels row
                if !labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(labels.prefix(3)) { label in
                            Text(label.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(label.swiftUIColor)
                                .cornerRadius(4)
                        }
                        if labels.count > 3 {
                            Text("+\(labels.count - 3)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Last interaction
            if let updatedAt = contact.updatedAt {
                Text(updatedAt.relativeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Date Extension

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - CRMContact Extension

extension CRMContact {
    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

#Preview {
    NavigationStack {
        ContactsView()
    }
    .frame(width: 390, height: 700)
}
