// CreateContactSheet.swift
// Quick contact creation during recording

import SwiftUI
import Contacts

struct CreateContactSheet: View {
    let onSave: (CRMContact) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var domain = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isCompany = false
    
    // EAI Company selection
    @State private var selectedCompanyId: UUID?
    @State private var availableCompanies: [CRMContact] = []
    @State private var isLoadingCompanies = false
    
    // iCloud contact picker for company
    @State private var showICloudPicker = false
    @State private var selectedICloudCompany: CNContact?
    
    // iCloud import picker (for importing full contact)
    @State private var showImportPicker = false
    @State private var importedFromICloud = false
    @State private var importedAppleContactId: String?
    
    @State private var isSaving = false
    @State private var error: String?
    
    private let repository = ContactRepository()
    private let contactsManager = ContactsManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Contact")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                // Import from iCloud section
                Section {
                    Button(action: { showImportPicker = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import from iCloud")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Select an existing contact to import")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                
                Section {
                    if importedFromICloud {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Imported from iCloud")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Clear") {
                                clearImportedData()
                            }
                            .font(.caption)
                        }
                    }
                    
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    // Company toggle
                    Toggle("This is a Company", isOn: $isCompany)
                        .toggleStyle(.switch)
                    
                    // Show company pickers only for individuals
                    if !isCompany {
                        // Original dropdown for EAI companies
                        eaiCompanyPicker
                        
                        // Button to browse iCloud contacts
                        iCloudBrowseButton
                    }
                    
                    TextField("Domain (optional)", text: $domain)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Phone (optional)", text: $phone)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Email (optional)", text: $email)
                        .textFieldStyle(.roundedBorder)
                }
                
                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Save button
            HStack {
                Spacer()
                
                Button(action: saveContact) {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Save & Assign")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 380, height: 420)
        .onAppear {
            loadCompanies()
        }
        .sheet(isPresented: $showICloudPicker) {
            ICloudContactPickerSheet(
                title: "Select Company",
                onSelect: { contact in
                    selectedICloudCompany = contact
                    selectedCompanyId = nil  // Clear EAI selection
                }
            )
        }
        .sheet(isPresented: $showImportPicker) {
            ICloudContactPickerSheet(
                title: "Import Contact",
                onSelect: { contact in
                    importContactFromICloud(contact)
                }
            )
        }
    }
    
    // MARK: - EAI Company Picker (Original Dropdown)
    
    private var eaiCompanyPicker: some View {
        HStack {
            Text("Company")
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isLoadingCompanies {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Picker("", selection: $selectedCompanyId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(availableCompanies) { company in
                        Text(company.name).tag(company.id as UUID?)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
                .onChange(of: selectedCompanyId) { newValue in
                    // Clear iCloud selection when EAI company selected
                    if newValue != nil {
                        selectedICloudCompany = nil
                    }
                }
            }
        }
    }
    
    // MARK: - iCloud Browse Button
    
    private var iCloudBrowseButton: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let selected = selectedICloudCompany {
                // Show selected iCloud company
                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(selected.organizationName.isEmpty ? selected.fullName : selected.organizationName)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { selectedICloudCompany = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                // Button to open iCloud picker
                Button(action: { showICloudPicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "icloud")
                            .foregroundColor(.blue)
                        
                        Text("Browse iCloud Contacts")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Load Companies
    
    private func loadCompanies() {
        isLoadingCompanies = true
        Task {
            do {
                let companies = try await repository.fetchCompanies()
                await MainActor.run {
                    self.availableCompanies = companies
                    self.isLoadingCompanies = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingCompanies = false
                    print("CreateContactSheet: Failed to load companies: \(error)")
                }
            }
        }
    }
    
    // MARK: - Import from iCloud
    
    private func importContactFromICloud(_ contact: CNContact) {
        // Set basic info
        name = contact.fullName
        
        // Set email if available
        if let primaryEmail = contact.primaryEmail {
            email = primaryEmail
        }
        
        // Set phone if available
        if let primaryPhone = contact.primaryPhone {
            phone = primaryPhone
        }
        
        // Check if this is a company contact
        if !contact.organizationName.isEmpty && contact.givenName.isEmpty && contact.familyName.isEmpty {
            // This is a company-only contact
            isCompany = true
        } else if !contact.organizationName.isEmpty {
            // This is a person with a company - need to find or create the company
            // For now, just note the company name for display
        }
        
        // Mark as imported and store the Apple Contact ID for linking
        importedFromICloud = true
        importedAppleContactId = contact.identifier
        
        // Clear any company selections since we're importing a full contact
        selectedCompanyId = nil
        selectedICloudCompany = nil
    }
    
    private func clearImportedData() {
        name = ""
        email = ""
        phone = ""
        domain = ""
        isCompany = false
        importedFromICloud = false
        importedAppleContactId = nil
        selectedCompanyId = nil
        selectedICloudCompany = nil
    }
    
    // MARK: - Save Contact
    
    private func saveContact() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Name is required"
            return
        }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespaces)
                let trimmedEmail = email.isEmpty ? nil : email.trimmingCharacters(in: .whitespaces)
                let trimmedPhone = phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespaces)
                let trimmedDomain = domain.isEmpty ? nil : domain.trimmingCharacters(in: .whitespaces)
                
                var companyName: String? = nil
                var companyId: UUID? = nil
                
                if isCompany {
                    companyName = trimmedName
                } else if let eaiCompanyId = selectedCompanyId,
                          let eaiCompany = availableCompanies.first(where: { $0.id == eaiCompanyId }) {
                    companyName = eaiCompany.name
                    companyId = eaiCompany.id
                } else if let iCloudContact = selectedICloudCompany {
                    // Import iCloud company
                    let importedCompany = try await importICloudCompany(iCloudContact)
                    companyName = importedCompany.name
                    companyId = importedCompany.id
                }
                
                let newContact = CRMContact(
                    appleContactId: importedAppleContactId,  // Use imported ID if available
                    name: trimmedName,
                    email: trimmedEmail,
                    phone: trimmedPhone,
                    company: companyName,
                    domain: trimmedDomain,
                    isCompany: isCompany,
                    companyId: companyId
                )
                
                var created = try await repository.createContact(newContact)
                
                // Only create a new iOS Contact if we didn't import from iCloud
                if importedAppleContactId == nil {
                    contactsManager.checkAuthorizationStatus()
                    if contactsManager.authorizationStatus == .authorized {
                        let nameParts = trimmedName.components(separatedBy: " ")
                        let firstName = nameParts.first ?? trimmedName
                        let lastName = nameParts.dropFirst().joined(separator: " ")
                        
                        do {
                            let appleContact = try await contactsManager.createContact(
                                firstName: firstName,
                                lastName: lastName.isEmpty ? "" : lastName,
                                email: trimmedEmail,
                                phone: trimmedPhone,
                                company: companyName
                            )
                            
                            created.appleContactId = appleContact.identifier
                            created = try await repository.updateContact(created)
                            print("CreateContactSheet: Successfully linked iOS Contact: \(appleContact.identifier)")
                        } catch {
                            print("CreateContactSheet: Failed to create iOS Contact: \(error)")
                            print("CreateContactSheet: Contact was saved to E-AI but may not sync to iMessage")
                        }
                    } else {
                        print("CreateContactSheet: Contacts access not authorized - contact will not sync to iCloud")
                        print("CreateContactSheet: Authorization status: \(contactsManager.authorizationStatus.rawValue)")
                    }
                } else {
                    print("CreateContactSheet: Imported from iCloud with ID: \(importedAppleContactId!)")
                }
                
                await MainActor.run {
                    onSave(created)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to save: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
    
    private func importICloudCompany(_ iCloudContact: CNContact) async throws -> CRMContact {
        let companyName = iCloudContact.organizationName.isEmpty
            ? iCloudContact.fullName
            : iCloudContact.organizationName
        
        let companyContact = CRMContact(
            appleContactId: iCloudContact.identifier,
            name: companyName,
            email: iCloudContact.primaryEmail,
            phone: iCloudContact.primaryPhone,
            company: companyName,
            isCompany: true
        )
        
        let created = try await repository.createContact(companyContact)
        availableCompanies.append(created)
        return created
    }
}

// MARK: - iCloud Contact Picker Sheet

struct ICloudContactPickerSheet: View {
    var title: String = "iCloud Contacts"
    let onSelect: (CNContact) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var contacts: [CNContact] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var error: String?
    
    private let contactsManager = ContactsManager.shared
    
    var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.fullName.localizedCaseInsensitiveContains(searchText) ||
            contact.organizationName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search contacts...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading contacts...")
                Spacer()
            } else if let error = error {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else if filteredContacts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No contacts found")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(filteredContacts, id: \.identifier) { contact in
                    Button(action: {
                        onSelect(contact)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                if !contact.organizationName.isEmpty {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Text(contactInitials(contact))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            // Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.fullName.isEmpty ? contact.organizationName : contact.fullName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if !contact.organizationName.isEmpty && !contact.fullName.isEmpty {
                                    Text(contact.organizationName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadContacts()
        }
    }
    
    private func loadContacts() {
        isLoading = true
        Task {
            do {
                // Request access if needed
                if contactsManager.authorizationStatus != .authorized {
                    _ = await contactsManager.requestAccess()
                }
                
                let allContacts = try await contactsManager.fetchAllContacts()
                await MainActor.run {
                    self.contacts = allContacts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func contactInitials(_ contact: CNContact) -> String {
        let first = contact.givenName.prefix(1)
        let last = contact.familyName.prefix(1)
        if first.isEmpty && last.isEmpty {
            return "?"
        }
        return "\(first)\(last)".uppercased()
    }
}

#Preview {
    CreateContactSheet(onSave: { _ in })
}
