// ContactDetailView.swift
// Full record for a single business contact

import SwiftUI

struct ContactDetailView: View {
    let contact: CRMContact
    
    @StateObject private var viewModel: ContactDetailViewModel
    @State private var showAddComment = false
    @State private var showEditContact = false
    @State private var showAddContactToRecording = false
    @State private var showEmailCompose = false
    @State private var selectedRecordingId: UUID?
    @State private var expandedEmailThreadId: String?
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
                    
                    // Associated company (for individuals)
                    associatedCompanySection
                    
                    // Associated people (for companies)
                    associatedPeopleSection
                    
                    // Custom fields
                    customFields
                    
                    // Sync iMessages button
                    syncIMessagesButton
                    
                    // Sync Emails button
                    syncEmailsButton
                    
                    // Send Email button
                    sendEmailButton
                    
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
        .background(Color.white)
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
        .sheet(isPresented: $showEmailCompose) {
            EmailComposeView(contact: viewModel.contact) {
                viewModel.loadTimeline()
            }
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
            viewModel.loadAssociations()
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
            
            // Quick action buttons
            quickActionButtons
            
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
    
    // MARK: - Quick Action Buttons
    
    private var quickActionButtons: some View {
        HStack(spacing: 24) {
            // Phone actions - Call and Text if phone exists, Add Phone if not
            if let phone = viewModel.contact.phone {
                // Call button
                Button(action: { initiatePhoneCall(phone) }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "phone.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Text("Call")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Text button
                Button(action: { initiateTextMessage(phone) }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "message.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Text("Text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Add Phone button
                Button(action: { showEditContact = true }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        Text("Add Phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Email action - Email if exists, Add Email if not
            if viewModel.contact.email != nil {
                Button(action: { showEmailCompose = true }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Text("Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Add Email button
                Button(action: { showEditContact = true }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        Text("Add Email")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Quick Action Helpers
    
    private func initiatePhoneCall(_ phone: String) {
        // Clean the phone number - remove spaces, dashes, parentheses
        let cleanedPhone = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "tel:\(cleanedPhone)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func initiateTextMessage(_ phone: String) {
        // Clean the phone number - remove spaces, dashes, parentheses
        let cleanedPhone = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "sms:\(cleanedPhone)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Associated Company Section (for individuals)
    
    @ViewBuilder
    private var associatedCompanySection: some View {
        if !viewModel.contact.isCompany, let companyContact = viewModel.companyContact {
            NavigationLink(destination: ContactDetailView(contact: companyContact)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Associated Company")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        // Company avatar
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        
                        // Company name
                        VStack(alignment: .leading, spacing: 2) {
                            Text(companyContact.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Company")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else if !viewModel.contact.isCompany && viewModel.isLoadingAssociations {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
    
    // MARK: - Associated People Section (for companies)
    
    @ViewBuilder
    private var associatedPeopleSection: some View {
        if viewModel.contact.isCompany {
            VStack(alignment: .leading, spacing: 12) {
                Text("Associated People")
                    .font(.headline)
                
                if viewModel.isLoadingAssociations {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.associatedPeople.isEmpty {
                    Text("No people associated with this company")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.associatedPeople) { person in
                        NavigationLink(destination: ContactDetailView(contact: person)) {
                            HStack(spacing: 12) {
                                // Person avatar
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    
                                    Text(person.initials)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.accentColor)
                                }
                                
                                // Person name
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    if let email = person.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else if let phone = person.phone {
                                        Text(phone)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(12)
        }
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
    
    // MARK: - Sync Emails Button
    
    @ViewBuilder
    private var syncEmailsButton: some View {
        if viewModel.contact.email != nil {
            Button(action: { viewModel.syncEmails() }) {
                HStack {
                    if viewModel.isSyncingEmails {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                        Text("Syncing...")
                    } else if let result = viewModel.emailSyncResult {
                        switch result {
                        case .success(let count):
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            if count > 0 {
                                Text("Synced \(count) emails")
                            } else {
                                Text("No new emails")
                            }
                        case .error(let message):
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(message)
                                .lineLimit(1)
                        }
                    } else if !viewModel.isGmailConnected {
                        Image(systemName: "envelope.badge.shield.half.filled")
                        Text("Connect Gmail in Settings")
                    } else {
                        Image(systemName: "envelope.badge.circle.fill")
                        Text("Sync Emails")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSyncingEmails || !viewModel.isGmailConnected)
        }
    }
    
    // MARK: - Send Email Button
    
    @ViewBuilder
    private var sendEmailButton: some View {
        if viewModel.contact.email != nil && viewModel.isGmailConnected {
            Button(action: { showEmailCompose = true }) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Send Email")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
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
            } else if viewModel.timelineItems.isEmpty && viewModel.emailThreads.isEmpty {
                Text("No interactions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                // Email threads section (grouped by thread)
                if !viewModel.emailThreads.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.emailThreads) { thread in
                            TimelineEmailThreadRow(
                                thread: thread,
                                isExpanded: expandedEmailThreadId == thread.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if expandedEmailThreadId == thread.id {
                                            expandedEmailThreadId = nil
                                        } else {
                                            expandedEmailThreadId = thread.id
                                        }
                                    }
                                },
                                onReply: { body in
                                    try await viewModel.replyToTimelineThread(thread, body: body)
                                }
                            )
                        }
                    }
                }
                
                // Other timeline items (recordings, comments, messages - no individual emails)
                ForEach(viewModel.timelineItems) { item in
                    TimelineItemView(item: item, onAddContact: { recordingId in
                        selectedRecordingId = recordingId
                        showAddContactToRecording = true
                    })
                }
            }
        }
        .sheet(isPresented: $showAddContactToRecording) {
            if let recordingId = selectedRecordingId {
                AddContactToRecordingByIdSheet(recordingId: recordingId) {
                    viewModel.loadTimeline()
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
    var onAddContact: ((UUID) -> Void)? = nil
    
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
                    
                    // Add contact button (only for recordings)
                    if item.type == .recording, let recordingId = item.sourceId {
                        Button(action: { onAddContact?(recordingId) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                        .help("Add contact to recording")
                    }
                    
                    Spacer()
                    
                    Text(item.date.relativeFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Contact badges (for recordings)
                if item.type == .recording && !item.contacts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(item.contacts, id: \.id) { contact in
                                HStack(spacing: 4) {
                                    if contact.isCompany {
                                        Image(systemName: "building.2.fill")
                                            .font(.caption2)
                                    }
                                    Text(contact.name)
                                }
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.teal)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                        }
                    }
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
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

// MARK: - Add Contact to Recording Sheet (by ID)

struct AddContactToRecordingByIdSheet: View {
    let recordingId: UUID
    let onContactAdded: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var contacts: [CRMContact] = []
    @State private var existingContactIds: Set<UUID> = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    
    private let contactRepository = ContactRepository()
    private let recordingRepository = RecordingRepository()
    
    var filteredContacts: [CRMContact] {
        let available = contacts.filter { !existingContactIds.contains($0.id) }
        
        if searchText.isEmpty {
            return available
        }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Contact to Recording")
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
            
            // Error message
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading contacts...")
                Spacer()
            } else if filteredContacts.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No more contacts to add" : "No matching contacts")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(filteredContacts) { contact in
                    Button(action: {
                        addContact(contact)
                    }) {
                        HStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(contact.isCompany ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                
                                if contact.isCompany {
                                    Image(systemName: "building.2.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else {
                                    Text(contact.initials)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            
                            // Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if let company = contact.company, !contact.isCompany {
                                    Text(company)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 350, height: 450)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        isLoading = true
        Task {
            do {
                async let allContacts = contactRepository.fetchAllContacts()
                async let speakers = recordingRepository.fetchRecordingSpeakers(recordingId: recordingId)
                
                let (contactsResult, speakersResult) = try await (allContacts, speakers)
                
                await MainActor.run {
                    self.contacts = contactsResult
                    self.existingContactIds = Set(speakersResult.compactMap { $0.contactId })
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
    
    private func addContact(_ contact: CRMContact) {
        isSaving = true
        error = nil
        
        Task {
            do {
                // Get existing speakers to determine next speaker number
                let existingSpeakers = try await recordingRepository.fetchRecordingSpeakers(recordingId: recordingId)
                let nextSpeakerNumber = (existingSpeakers.map { $0.speakerNumber }.max() ?? 0) + 1
                
                // Create new speaker
                let speaker = RecordingSpeaker(
                    id: UUID(),
                    recordingId: recordingId,
                    speakerNumber: nextSpeakerNumber,
                    contactId: contact.id,
                    isUser: false
                )
                
                _ = try await recordingRepository.createRecordingSpeaker(speaker)
                
                await MainActor.run {
                    onContactAdded()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to add contact: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
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
