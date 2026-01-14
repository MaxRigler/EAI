// EmailComposeView.swift
// Email composition sheet for sending emails from E-AI

import SwiftUI

struct EmailComposeView: View {
    let contact: CRMContact
    let onSend: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var emailBody = ""
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
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
                VStack(alignment: .leading, spacing: 16) {
                    // Recipient
                    recipientField
                    
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
        .frame(width: 400, height: 500)
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
            Text("Your email to \(contact.name) has been sent successfully.")
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
    
    // MARK: - Fields
    
    private var recipientField: some View {
        HStack {
            Text("To:")
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            HStack(spacing: 8) {
                // Contact avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 28, height: 28)
                    
                    Text(contact.initials)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(contact.email ?? "No email")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
    }
    
    private var subjectField: some View {
        HStack {
            Text("Subject:")
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            TextField("", text: $subject)
                .textFieldStyle(.plain)
        }
    }
    
    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Message:")
                .foregroundColor(.secondary)
            
            TextEditor(text: $emailBody)
                .font(.body)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Helpers
    
    private var canSend: Bool {
        !subject.trimmingCharacters(in: .whitespaces).isEmpty &&
        !emailBody.trimmingCharacters(in: .whitespaces).isEmpty &&
        contact.email != nil
    }
    
    /// Normalizes email body by joining lines within paragraphs
    /// This ensures text flows naturally in email clients instead of having hard line breaks
    private func normalizeEmailBody(_ text: String) -> String {
        // First, normalize all line endings to \n (handle Windows \r\n and old Mac \r)
        var normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        print("EmailComposeView: Original text length: \(text.count)")
        print("EmailComposeView: Normalized line endings")
        
        // Split by double newlines to identify paragraph breaks
        let paragraphs = normalized.components(separatedBy: "\n\n")
        print("EmailComposeView: Found \(paragraphs.count) paragraphs")
        
        // For each paragraph, join single-line breaks into spaces
        let normalizedParagraphs = paragraphs.map { paragraph -> String in
            let lines = paragraph.components(separatedBy: "\n")
            let joinedLines = lines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            print("EmailComposeView: Paragraph has \(lines.count) lines -> joined into \(joinedLines.count) chars")
            return joinedLines
        }
        
        // Rejoin paragraphs with double newlines
        let result = normalizedParagraphs
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        
        print("EmailComposeView: Final text length: \(result.count)")
        print("EmailComposeView: First 200 chars: \(String(result.prefix(200)))")
        
        return result
    }
    
    private func sendEmail() {
        guard canSend else { return }
        
        isSending = true
        
        Task {
            do {
                // Normalize body text to remove hard line breaks within paragraphs
                let normalizedBody = normalizeEmailBody(emailBody)
                
                let _ = try await EmailSyncService.shared.sendEmail(
                    to: contact,
                    subject: subject.trimmingCharacters(in: .whitespaces),
                    body: normalizedBody
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
