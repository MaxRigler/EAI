// CreateContactSheet.swift
// Quick contact creation during recording

import SwiftUI

struct CreateContactSheet: View {
    let onSave: (CRMContact) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var company = ""
    @State private var domain = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var isCompany = false
    @State private var selectedCompanyId: UUID?
    @State private var availableCompanies: [CRMContact] = []
    @State private var isSaving = false
    @State private var isLoadingCompanies = false
    @State private var error: String?
    
    private let repository = ContactRepository()
    
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
                Section {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    // Company toggle
                    Toggle("This is a Company", isOn: $isCompany)
                        .toggleStyle(.switch)
                    
                    // Show company picker only for individuals
                    if !isCompany {
                        companyPicker
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
        .frame(width: 360, height: 420)
        .onAppear {
            loadCompanies()
        }
    }
    
    // MARK: - Company Picker
    
    private var companyPicker: some View {
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
                
                // For companies, use the name as company field too
                // For individuals with a selected company, get the company name
                var companyName: String? = nil
                if isCompany {
                    companyName = trimmedName
                } else if let companyId = selectedCompanyId,
                          let selectedCompany = availableCompanies.first(where: { $0.id == companyId }) {
                    companyName = selectedCompany.name
                }
                
                let newContact = CRMContact(
                    name: trimmedName,
                    email: trimmedEmail,
                    phone: trimmedPhone,
                    company: companyName,
                    domain: trimmedDomain,
                    isCompany: isCompany,
                    companyId: isCompany ? nil : selectedCompanyId
                )
                
                var created = try await repository.createContact(newContact)
                
                // Create iOS Contact for iCloud sync
                let contactsManager = ContactsManager.shared
                if contactsManager.authorizationStatus == .authorized {
                    // Parse name into first/last
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
                        
                        // Link the iOS Contact to the CRM Contact
                        created.appleContactId = appleContact.identifier
                        created = try await repository.updateContact(created)
                        print("CreateContactSheet: Created and linked iOS Contact: \(appleContact.identifier)")
                    } catch {
                        // Log but don't fail - Supabase save succeeded
                        print("CreateContactSheet: Failed to create iOS Contact: \(error)")
                    }
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

}

#Preview {
    CreateContactSheet(onSave: { _ in })
}
