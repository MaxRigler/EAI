// ContactDetailView.swift
// Full record for a single business contact

import SwiftUI

struct ContactDetailView: View {
    let contact: CRMContact
    
    @StateObject private var viewModel: ContactDetailViewModel
    @State private var showAddComment = false
    @State private var showEditContact = false
    @Environment(\.dismiss) private var dismiss
    
    init(contact: CRMContact) {
        self.contact = contact
        self._viewModel = StateObject(wrappedValue: ContactDetailViewModel(contact: contact))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("All Contacts")
                            .font(.body)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: { showEditContact = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 20) {
                    // Contact header
                    contactHeader
                    
                    // Contact info
                    contactInfo
                    
                    // Custom fields
                    customFields
                    
                    // Sync iMessages button
                    syncIMessagesButton
                    
                    // Add comment button
                    addCommentButton
                    
                    // Tasks section
                    tasksSection
                    
                    // Timeline
                    timeline
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddComment) {
            AddCommentSheet(contact: contact, onSave: { comment in
                viewModel.addComment(comment)
            })
        }
        .sheet(isPresented: $showEditContact) {
            EditContactSheet(contact: viewModel.contact, onSave: { updated in
                viewModel.saveContact(updated)
            })
        }
        .alert("Full Disk Access Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Open System Settings") {
                viewModel.openFullDiskAccessSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("E-AI needs Full Disk Access to read your iMessage history.\n\nGo to System Settings → Privacy & Security → Full Disk Access → Add E-AI to the allowed apps.")
        }
        .onAppear {
            viewModel.loadTimeline()
            viewModel.loadTasks()
        }
    }
    
    // MARK: - Contact Header
    
    private var contactHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Text(viewModel.contact.initials)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            
            // Name and company
            VStack(spacing: 4) {
                Text(viewModel.contact.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let company = viewModel.contact.company {
                    Text(company)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Tags
            if !viewModel.contact.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.contact.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Contact Info
    
    private var contactInfo: some View {
        VStack(spacing: 12) {
            if let phone = viewModel.contact.phone {
                InfoRow(icon: "phone.fill", label: "Phone", value: phone)
            }
            
            if let email = viewModel.contact.email {
                InfoRow(icon: "envelope.fill", label: "Email", value: email)
            }
            
            if let businessType = viewModel.contact.businessType {
                InfoRow(icon: "building.2.fill", label: "Business Type", value: businessType)
            }
            
            if let dealStage = viewModel.contact.dealStage {
                InfoRow(icon: "chart.bar.fill", label: "Deal Stage", value: dealStage)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Custom Fields
    
    @ViewBuilder
    private var customFields: some View {
        if !viewModel.contact.customFields.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Fields")
                    .font(.headline)
                
                ForEach(Array(viewModel.contact.customFields.keys.sorted()), id: \.self) { key in
                    if let value = viewModel.contact.customFields[key] {
                        InfoRow(icon: "tag.fill", label: key, value: value)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Sync iMessages Button
    
    @ViewBuilder
    private var syncIMessagesButton: some View {
        if viewModel.canSyncIMessages {
            Button(action: { viewModel.syncIMessages() }) {
                HStack {
                    if viewModel.isSyncingMessages {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                        Text("Syncing...")
                    } else if let result = viewModel.syncResult {
                        switch result {
                        case .success(let count):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            if count > 0 {
                                Text("Synced \(count) messages")
                            } else {
                                Text("No new messages")
                            }
                        case .error(let message):
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(message)
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: "message.badge.circle.fill")
                        Text("Sync iMessages")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.teal.opacity(0.1))
                .foregroundColor(.teal)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSyncingMessages)
        }
    }
    
    // MARK: - Add Comment Button
    
    private var addCommentButton: some View {
        Button(action: { showAddComment = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Comment")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tasks Section
    
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with toggle
            HStack {
                Text("Tasks")
                    .font(.headline)
                
                Spacer()
                
                // Open/Completed toggle
                Picker("Filter", selection: $viewModel.selectedTaskFilter) {
                    ForEach(ContactDetailViewModel.TaskFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            
            // Tasks list
            if viewModel.isLoadingTasks {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if viewModel.filteredTasks.isEmpty {
                Text(viewModel.selectedTaskFilter == .open ? "No open tasks" : "No completed tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.filteredTasks) { task in
                    ContactTaskRow(task: task, onToggle: {
                        viewModel.toggleTaskCompletion(task)
                    })
                }
            }
        }
    }
    
    // MARK: - Timeline
    
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.timelineItems.isEmpty {
                Text("No interactions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.timelineItems) { item in
                    TimelineItemView(item: item)
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Timeline Item View

struct TimelineItemView: View {
    let item: TimelineItem
    @State private var isExpanded = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(item.iconColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: item.icon)
                    .font(.system(size: 14))
                    .foregroundColor(item.iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(item.date.relativeFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Summary text - expandable with markdown rendering
                TimelineMarkdownText(text: item.content)
                    .lineLimit(isExpanded ? nil : 3)
                    .textSelection(.enabled)
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                
                // Show more/less button
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Contact Task Row

struct ContactTaskRow: View {
    let task: AppTask
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.description)
                    .font(.subheadline)
                    .strikethrough(task.status == .completed)
                    .foregroundColor(task.status == .completed ? .secondary : .primary)
                    .lineLimit(2)
                
                // Call context
                if let recordingTypeName = task.recordingTypeName {
                    HStack(spacing: 4) {
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                        Text(recordingTypeName)
                        if let recordingTime = task.recordingTime {
                            Text("•")
                            Text(recordingTime.formatted(date: .omitted, time: .shortened))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Timeline Markdown Text View

/// A view that renders markdown-formatted text with proper styling for timeline items
struct TimelineMarkdownText: View {
    let text: String
    
    var body: some View {
        Text(parseMarkdown(text))
    }
    
    /// Parse markdown into AttributedString
    private func parseMarkdown(_ markdown: String) -> AttributedString {
        var result = AttributedString()
        
        let lines = markdown.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let parsedLine = parseLine(line)
            result.append(parsedLine)
            
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }
    
    /// Parse a single line of markdown
    private func parseLine(_ line: String) -> AttributedString {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Handle headings (## and ###)
        if trimmedLine.hasPrefix("###") {
            let content = trimmedLine.dropFirst(3).trimmingCharacters(in: .whitespaces)
            var attr = AttributedString("\n" + content)
            attr.font = .headline
            attr.foregroundColor = .primary
            return attr
        } else if trimmedLine.hasPrefix("##") {
            let content = trimmedLine.dropFirst(2).trimmingCharacters(in: .whitespaces)
            var attr = AttributedString("\n" + content)
            attr.font = .title3.bold()
            attr.foregroundColor = .primary
            return attr
        }
        
        // Parse inline bold (**text**)
        return parseInlineFormatting(trimmedLine)
    }
    
    /// Parse inline formatting like **bold**
    private func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text
        
        while !remaining.isEmpty {
            if let boldStart = remaining.range(of: "**") {
                // Add text before the bold marker
                let beforeBold = String(remaining[..<boldStart.lowerBound])
                if !beforeBold.isEmpty {
                    var beforeAttr = AttributedString(beforeBold)
                    beforeAttr.font = .caption
                    beforeAttr.foregroundColor = .secondary
                    result.append(beforeAttr)
                }
                
                // Find the closing **
                let afterStart = remaining[boldStart.upperBound...]
                if let boldEnd = afterStart.range(of: "**") {
                    let boldContent = String(afterStart[..<boldEnd.lowerBound])
                    var boldAttr = AttributedString(boldContent)
                    boldAttr.font = .caption.bold()
                    boldAttr.foregroundColor = .secondary
                    result.append(boldAttr)
                    
                    remaining = String(afterStart[boldEnd.upperBound...])
                } else {
                    // No closing **, treat as regular text
                    var attr = AttributedString(String(remaining))
                    attr.font = .caption
                    attr.foregroundColor = .secondary
                    result.append(attr)
                    remaining = ""
                }
            } else {
                // No more bold markers
                var attr = AttributedString(remaining)
                attr.font = .caption
                attr.foregroundColor = .secondary
                result.append(attr)
                remaining = ""
            }
        }
        
        return result
    }
}

// MARK: - Add Comment Sheet

struct AddCommentSheet: View {
    let contact: CRMContact
    let onSave: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var commentText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Add Comment")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    onSave(commentText)
                    dismiss()
                }
                .disabled(commentText.isEmpty)
            }
            .padding()
            
            Divider()
            
            // Comment text area
            TextEditor(text: $commentText)
                .font(.body)
                .padding()
            
        }
        .frame(width: 350, height: 300)
    }
}

// MARK: - Edit Contact Sheet

struct EditContactSheet: View {
    let contact: CRMContact
    let onSave: (CRMContact) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var company: String
    @State private var domain: String
    @State private var businessType: String
    @State private var dealStage: String
    @State private var isCompany: Bool
    @State private var selectedCompanyId: UUID?
    @State private var availableCompanies: [CRMContact] = []
    @State private var isLoadingCompanies = false
    
    private let repository = ContactRepository()
    
    init(contact: CRMContact, onSave: @escaping (CRMContact) -> Void) {
        self.contact = contact
        self.onSave = onSave
        _name = State(initialValue: contact.name)
        _email = State(initialValue: contact.email ?? "")
        _phone = State(initialValue: contact.phone ?? "")
        _company = State(initialValue: contact.company ?? "")
        _domain = State(initialValue: contact.domain ?? "")
        _businessType = State(initialValue: contact.businessType ?? "")
        _dealStage = State(initialValue: contact.dealStage ?? "")
        _isCompany = State(initialValue: contact.isCompany)
        _selectedCompanyId = State(initialValue: contact.companyId)
    }
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Edit Contact")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    saveChanges()
                }
                .disabled(!canSave)
            }
            .padding()
            
            Divider()
            
            Form {
                // Company toggle at the top
                Section {
                    Toggle("This is a Company", isOn: $isCompany)
                        .toggleStyle(.switch)
                }
                
                Section {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                    TextField("Phone", text: $phone)
                    
                    // Company picker (only for individuals)
                    if !isCompany {
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
                                    ForEach(availableCompanies.filter { $0.id != contact.id }) { company in
                                        Text(company.name).tag(company.id as UUID?)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                    
                    TextField("Domain", text: $domain)
                    TextField("Business Type", text: $businessType)
                    TextField("Deal Stage", text: $dealStage)
                }
            }
            .padding()
        }
        .frame(width: 380, height: 480)
        .onAppear {
            loadCompanies()
        }
    }
    
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
                    print("EditContactSheet: Failed to load companies: \(error)")
                }
            }
        }
    }
    
    private func saveChanges() {
        // Get company name from selected company if applicable
        var companyName = company.isEmpty ? nil : company
        if !isCompany, let companyId = selectedCompanyId,
           let selectedCompany = availableCompanies.first(where: { $0.id == companyId }) {
            companyName = selectedCompany.name
        }
        
        let updatedContact = CRMContact(
            id: contact.id,
            appleContactId: contact.appleContactId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            businessType: businessType.isEmpty ? nil : businessType,
            company: companyName,
            domain: domain.isEmpty ? nil : domain,
            dealStage: dealStage.isEmpty ? nil : dealStage,
            tags: contact.tags,
            customFields: contact.customFields,
            isCompany: isCompany,
            companyId: isCompany ? nil : selectedCompanyId,
            createdAt: contact.createdAt,
            updatedAt: Date()
        )
        
        onSave(updatedContact)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ContactDetailView(contact: CRMContact(
            id: UUID(),
            appleContactId: nil,
            name: "John Smith",
            email: "john@example.com",
            phone: "+1 555 123 4567",
            businessType: "Real Estate",
            company: "Smith Properties",
            dealStage: "Negotiation",
            tags: ["VIP", "Hot Lead"],
            customFields: ["Source": "Referral"],
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    .frame(width: 390, height: 700)
}
