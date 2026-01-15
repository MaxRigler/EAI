// EmailComposeView.swift
// Email composition sheet for sending emails from E-AI

import SwiftUI

// MARK: - Email Recipient Model

struct EmailRecipient: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let email: String
    let contactId: UUID?
    
    init(id: UUID = UUID(), name: String, email: String, contactId: UUID? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.contactId = contactId
    }
    
    init(from contact: CRMContact) {
        self.id = UUID()
        self.name = contact.name
        self.email = contact.email ?? ""
        self.contactId = contact.id
    }
    
    var initials: String {
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Active Field Enum

enum RecipientFieldType: Equatable {
    case to
    case cc
    case bcc
}

// MARK: - Email Compose View

struct EmailComposeView: View {
    let contact: CRMContact
    let onSend: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    // Recipients
    @State private var toRecipients: [EmailRecipient] = []
    @State private var ccRecipients: [EmailRecipient] = []
    @State private var bccRecipients: [EmailRecipient] = []
    
    // Text fields for adding new recipients
    @State private var toSearchText = ""
    @State private var ccSearchText = ""
    @State private var bccSearchText = ""
    
    // Suggestions
    @State private var suggestedContacts: [CRMContact] = []
    @State private var activeField: RecipientFieldType? = nil
    @State private var isSearching = false
    
    // Email content
    @State private var subject = ""
    @State private var emailBody = ""
    
    // UI state
    @State private var showCc = false
    @State private var showBcc = false
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    // Search debounce
    @State private var searchTask: Task<Void, Never>?
    
    private let contactRepository = ContactRepository()
    
    init(contact: CRMContact, onSend: (() -> Void)? = nil) {
        self.contact = contact
        self.onSend = onSend
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // To field
                    recipientField(
                        label: "To:",
                        recipients: $toRecipients,
                        searchText: $toSearchText,
                        fieldType: .to,
                        showToggle: true
                    )
                    
                    // CC field
                    if showCc {
                        Divider().padding(.leading, 50)
                        recipientField(
                            label: "Cc:",
                            recipients: $ccRecipients,
                            searchText: $ccSearchText,
                            fieldType: .cc,
                            showToggle: false
                        )
                    }
                    
                    // BCC field
                    if showBcc {
                        Divider().padding(.leading, 50)
                        recipientField(
                            label: "Bcc:",
                            recipients: $bccRecipients,
                            searchText: $bccSearchText,
                            fieldType: .bcc,
                            showToggle: false
                        )
                    }
                    
                    Divider()
                    
                    // Subject
                    subjectField
                    
                    Divider()
                    
                    // Body
                    bodyField
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Initialize with the original contact as first recipient
            if let email = contact.email, !email.isEmpty {
                toRecipients = [EmailRecipient(from: contact)]
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Email Sent", isPresented: $showSuccess) {
            Button("OK") {
                onSend?()
                dismiss()
            }
        } message: {
            Text("Your email has been sent successfully.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            
            Spacer()
            
            Text("New Email")
                .font(.headline)
            
            Spacer()
            
            Button(action: sendEmail) {
                if isSending {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 50)
                } else {
                    Text("Send")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(canSend ? .accentColor : .secondary)
            .disabled(!canSend || isSending)
        }
        .padding()
    }
    
    // MARK: - Recipient Field
    
    private func recipientField(
        label: String,
        recipients: Binding<[EmailRecipient]>,
        searchText: Binding<String>,
        fieldType: RecipientFieldType,
        showToggle: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
                    .padding(.top, 8)
                
                // Recipients flow layout
                FlowLayout(spacing: 6) {
                    // Existing recipient chips
                    ForEach(recipients.wrappedValue) { recipient in
                        recipientChip(recipient: recipient) {
                            recipients.wrappedValue.removeAll { $0.id == recipient.id }
                        }
                    }
                    
                    // Text field for adding more
                    TextField("Add recipient", text: searchText)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 120)
                        .onSubmit {
                            addManualRecipient(searchText: searchText, recipients: recipients)
                        }
                        .onChange(of: searchText.wrappedValue) { newValue in
                            activeField = fieldType
                            searchContacts(query: newValue)
                        }
                }
                
                Spacer(minLength: 0)
                
                // Cc/Bcc toggle button
                if showToggle && (!showCc || !showBcc) {
                    Button(action: {
                        if !showCc {
                            showCc = true
                        } else if !showBcc {
                            showBcc = true
                        }
                    }) {
                        Text(!showCc ? "Cc/Bcc" : "Bcc")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.vertical, 8)
            
            // Suggestions dropdown
            if activeField == fieldType && !suggestedContacts.isEmpty && !searchText.wrappedValue.isEmpty {
                suggestionsView(searchText: searchText, recipients: recipients)
            }
        }
    }
    
    // MARK: - Recipient Chip
    
    private func recipientChip(recipient: EmailRecipient, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            // Initials
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 22, height: 22)
                
                Text(recipient.initials)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.accentColor)
            }
            
            // Name
            Text(recipient.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Suggestions View
    
    private func suggestionsView(
        searchText: Binding<String>,
        recipients: Binding<[EmailRecipient]>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestedContacts.prefix(5)) { contact in
                Button(action: {
                    addContactAsRecipient(contact, recipients: recipients, searchText: searchText)
                }) {
                    HStack(spacing: 10) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: 28, height: 28)
                            
                            Text(contact.initials)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        
                        // Name and email
                        VStack(alignment: .leading, spacing: 1) {
                            Text(contact.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            if let email = contact.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor))
                
                if contact.id != suggestedContacts.prefix(5).last?.id {
                    Divider().padding(.leading, 50)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.leading, 48)
        .padding(.trailing, 8)
    }
    
    // MARK: - Subject and Body Fields
    
    private var subjectField: some View {
        HStack {
            Text("Subject:")
                .foregroundColor(.secondary)
                .frame(width: 55, alignment: .leading)
            
            TextField("", text: $subject)
                .textFieldStyle(.plain)
        }
        .padding(.vertical, 8)
    }
    
    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Message:")
                .foregroundColor(.secondary)
            
            TextEditor(text: $emailBody)
                .font(.body)
                .frame(minHeight: 180)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Search and Add Logic
    
    private func searchContacts(query: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            suggestedContacts = []
            return
        }
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await contactRepository.searchContacts(query: query)
                
                // Filter out contacts already added as recipients
                let existingIds = Set(
                    toRecipients.compactMap { $0.contactId } +
                    ccRecipients.compactMap { $0.contactId } +
                    bccRecipients.compactMap { $0.contactId }
                )
                
                // Also filter to only those with email addresses
                let filtered = results.filter { contact in
                    !existingIds.contains(contact.id) && contact.email != nil && !contact.email!.isEmpty
                }
                
                await MainActor.run {
                    suggestedContacts = filtered
                }
            } catch {
                print("EmailComposeView: Search failed: \(error)")
            }
        }
    }
    
    private func addContactAsRecipient(
        _ contact: CRMContact,
        recipients: Binding<[EmailRecipient]>,
        searchText: Binding<String>
    ) {
        guard let email = contact.email, !email.isEmpty else { return }
        
        let recipient = EmailRecipient(from: contact)
        recipients.wrappedValue.append(recipient)
        searchText.wrappedValue = ""
        suggestedContacts = []
        activeField = nil
    }
    
    private func addManualRecipient(
        searchText: Binding<String>,
        recipients: Binding<[EmailRecipient]>
    ) {
        let text = searchText.wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        
        // Check if it looks like an email address
        if text.contains("@") {
            let recipient = EmailRecipient(name: text, email: text)
            recipients.wrappedValue.append(recipient)
            searchText.wrappedValue = ""
            suggestedContacts = []
            activeField = nil
        }
    }
    
    // MARK: - Helpers
    
    private var canSend: Bool {
        !toRecipients.isEmpty &&
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !emailBody.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Normalizes email body by joining lines within paragraphs
    private func normalizeEmailBody(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        let paragraphs = normalized.components(separatedBy: "\n\n")
        
        let normalizedParagraphs = paragraphs.map { paragraph -> String in
            let lines = paragraph.components(separatedBy: "\n")
            let joinedLines = lines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return joinedLines
        }
        
        return normalizedParagraphs
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
    
    private func sendEmail() {
        guard canSend else { return }
        
        isSending = true
        
        Task {
            do {
                let normalizedBody = normalizeEmailBody(emailBody)
                
                // Build recipient lists
                let toEmails = toRecipients.map { $0.email }
                let ccEmails = ccRecipients.map { $0.email }
                let bccEmails = bccRecipients.map { $0.email }
                
                // Send via Gmail API with multiple recipients
                let _ = try await EmailSyncService.shared.sendEmailToMultiple(
                    toEmails: toEmails,
                    subject: subject.trimmingCharacters(in: .whitespaces),
                    body: normalizedBody,
                    cc: ccEmails.isEmpty ? nil : ccEmails,
                    bcc: bccEmails.isEmpty ? nil : bccEmails,
                    primaryContactId: contact.id
                )
                
                await MainActor.run {
                    isSending = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = calculateLayout(proposal: proposal, subviews: subviews)
        
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                let position = result.positions[index]
                subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
            }
        }
    }
    
    private func calculateLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }
        
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    EmailComposeView(
        contact: CRMContact(
            id: UUID(),
            name: "Max",
            email: "max@thercngroup.com",
            phone: "9147297830",
            company: "The RCN Group"
        )
    )
}
