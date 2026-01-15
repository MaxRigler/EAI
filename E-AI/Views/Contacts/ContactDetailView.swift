// ContactDetailView.swift
// Full record for a single business contact

import SwiftUI
import Contacts

struct ContactDetailView: View {
    let contact: CRMContact
    
    @StateObject private var viewModel: ContactDetailViewModel
    @State private var showAddComment = false
    @State private var showEditContact = false
    @State private var showAddContactToRecording = false
    @State private var showEmailCompose = false
    @State private var showAssociateCompany = false
    @State private var showAssociatePerson = false
    @State private var showManageLabels = false
    @State private var selectedRecordingId: UUID?
    @State private var expandedEmailThreadId: String?
    @Environment(\.dismiss) private var dismiss
    
    init(contact: CRMContact) {
        self.contact = contact
        self._viewModel = StateObject(wrappedValue: ContactDetailViewModel(contact: contact))
    }
    
    /// Returns the contact's own domain, or falls back to company's domain if associated
    private var effectiveDomain: String? {
        if let domain = viewModel.contact.domain, !domain.isEmpty {
            return domain
        }
        // Fall back to company's domain if this contact is associated with a company
        if let companyDomain = viewModel.companyContact?.domain, !companyDomain.isEmpty {
            return companyDomain
        }
        return nil
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
                    
                    // Labels section (above tasks)
                    labelsSection
                    
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
            }, onDelete: {
                viewModel.deleteContact()
            })
        }
        .sheet(isPresented: $showEmailCompose) {
            EmailComposeView(contact: viewModel.contact) {
                viewModel.loadTimeline()
            }
        }
        .sheet(isPresented: $showAssociateCompany) {
            AssociateCompanySheet(contact: viewModel.contact) { updatedContact in
                viewModel.saveContact(updatedContact)
            }
        }
        .sheet(isPresented: $showAssociatePerson) {
            AssociatePersonSheet(company: viewModel.contact) {
                viewModel.loadAssociations()
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
        .sheet(isPresented: $showManageLabels) {
            ManageLabelsSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadTimeline()
            viewModel.loadTasks()
            viewModel.loadAssociations()
            viewModel.loadLabels()
        }
        .onChange(of: viewModel.isDeleted) { isDeleted in
            if isDeleted {
                dismiss()
            }
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
            
            // Website action - Website if domain exists (own or company's), Add URL if not
            if let domain = effectiveDomain {
                Button(action: { openWebsite(domain) }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Text("Website")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                // Add URL button
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
                        
                        Text("Add URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            // Associate Company button - only show for non-company contacts without a company association
            if !viewModel.contact.isCompany && viewModel.contact.companyId == nil {
                Button(action: { showAssociateCompany = true }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        Text("Associate Company")
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
    
    private func openWebsite(_ domain: String) {
        // Normalize the domain - prepend https:// if not already a full URL
        var urlString = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }
        if let url = URL(string: urlString) {
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
                
                // Associate Person button
                Button(action: { showAssociatePerson = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        
                        Text("Associate Person")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
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
    
    // MARK: - Labels Section
    
    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with manage button
            HStack {
                Text("Labels")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showManageLabels = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Manage")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            // Labels display
            if viewModel.isLoadingLabels {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if viewModel.labels.isEmpty {
                Text("No labels assigned")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                // Horizontal scrollable row of label pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.labels) { label in
                            LabelPillView(label: label, onRemove: {
                                viewModel.removeLabel(label)
                            })
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
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
    let onDelete: (() -> Void)?
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
    @State private var showDeleteConfirmation = false
    
    private let repository = ContactRepository()
    
    init(contact: CRMContact, onSave: @escaping (CRMContact) -> Void, onDelete: (() -> Void)? = nil) {
        self.contact = contact
        self.onSave = onSave
        self.onDelete = onDelete
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
                
                // Delete section (only show if onDelete is provided)
                if onDelete != nil {
                    Section {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove from E-AI")
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    } footer: {
                        Text("This will remove the contact from E-AI only. Your iCloud contact will not be affected.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .frame(width: 380, height: onDelete != nil ? 560 : 480)
        .onAppear {
            loadCompanies()
        }
        .alert("Remove from E-AI?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                print("EditContactSheet: Delete cancelled")
            }
            Button("Remove", role: .destructive) {
                print("EditContactSheet: Remove confirmed, calling onDelete...")
                onDelete?()
                dismiss()
            }
        } message: {
            Text("This will permanently remove \"\(contact.name)\" from E-AI. This action cannot be undone.\n\nYour iCloud contact will not be affected.")
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

// MARK: - Associate Company Sheet

struct AssociateCompanySheet: View {
    let contact: CRMContact
    let onSave: (CRMContact) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var companies: [CRMContact] = []
    @State private var iCloudContacts: [CNContact] = []
    @State private var isLoading = true
    @State private var isLoadingICloud = false
    @State private var isSaving = false
    @State private var selectedTab = 0
    @State private var error: String?
    @State private var showCreateCompanySheet = false
    
    private let repository = ContactRepository()
    @ObservedObject private var contactsManager = ContactsManager.shared
    
    var filteredCompanies: [CRMContact] {
        if searchText.isEmpty {
            return companies
        }
        return companies.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredICloudContacts: [CNContact] {
        // Filter iCloud contacts that have an organization name (companies)
        let companyContacts = iCloudContacts.filter { 
            !$0.organizationName.isEmpty && 
            ($0.givenName.isEmpty || $0.familyName.isEmpty || $0.contactType == .organization)
        }
        
        if searchText.isEmpty {
            return companyContacts
        }
        return companyContacts.filter { 
            $0.organizationName.localizedCaseInsensitiveContains(searchText) ||
            "\($0.givenName) \($0.familyName)".localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Associate Company")
                    .font(.headline)
                Spacer()
                // Empty spacer for balance
                Button("Cancel") { dismiss() }
                    .opacity(0)
            }
            .padding()
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search companies...", text: $searchText)
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
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Tab picker
            Picker("Source", selection: $selectedTab) {
                Text("Existing Companies").tag(0)
                Text("iCloud Contacts").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Content
            if selectedTab == 0 {
                existingCompaniesTab
            } else {
                iCloudContactsTab
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadCompanies()
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == 1 && iCloudContacts.isEmpty {
                loadICloudContacts()
            }
        }
        .sheet(isPresented: $showCreateCompanySheet) {
            CreateCompanySheet { newCompany in
                // Associate the newly created company with the contact
                associateCompany(newCompany)
            }
        }
    }
    
    private var existingCompaniesTab: some View {
        Group {
            if isLoading {
                ProgressView("Loading companies...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Create New Company button at the top
                        Button(action: { showCreateCompanySheet = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create New Company")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text("Add a new company to EAI and iCloud")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        if filteredCompanies.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "building.2")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text(searchText.isEmpty ? "No companies found" : "No matching companies")
                                    .foregroundColor(.secondary)
                                Text("Create a new company above, or import from iCloud")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(filteredCompanies) { company in
                                CompanyRow(company: company, isSaving: isSaving) {
                                    associateCompany(company)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var iCloudContactsTab: some View {
        Group {
            if contactsManager.authorizationStatus != .authorized {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Contacts Access Required")
                        .font(.headline)
                    Text("Grant access to your contacts to import companies from iCloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Grant Access") {
                        Task {
                            await contactsManager.requestAccess()
                            if contactsManager.authorizationStatus == .authorized {
                                loadICloudContacts()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoadingICloud {
                ProgressView("Loading iCloud contacts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredICloudContacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "icloud")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No company contacts in iCloud" : "No matching contacts")
                        .foregroundColor(.secondary)
                    Text("Contacts with an organization name will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredICloudContacts, id: \.identifier) { contact in
                            ICloudCompanyRow(contact: contact, isSaving: isSaving) {
                                importAndAssociateFromICloud(contact)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func loadCompanies() {
        isLoading = true
        Task {
            do {
                let fetchedCompanies = try await repository.fetchCompanies()
                await MainActor.run {
                    self.companies = fetchedCompanies
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
    
    private func loadICloudContacts() {
        isLoadingICloud = true
        Task {
            do {
                let contacts = try await contactsManager.fetchAllContacts()
                await MainActor.run {
                    self.iCloudContacts = contacts
                    self.isLoadingICloud = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoadingICloud = false
                }
            }
        }
    }
    
    private func associateCompany(_ company: CRMContact) {
        isSaving = true
        
        // Create updated contact with company association
        var updatedContact = contact
        updatedContact.companyId = company.id
        updatedContact.company = company.name
        updatedContact.updatedAt = Date()
        
        Task {
            do {
                let saved = try await repository.updateContact(updatedContact)
                await MainActor.run {
                    onSave(saved)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
    
    private func importAndAssociateFromICloud(_ iCloudContact: CNContact) {
        isSaving = true
        
        Task {
            do {
                // Create a new company contact from the iCloud contact
                let companyName = iCloudContact.organizationName.isEmpty 
                    ? "\(iCloudContact.givenName) \(iCloudContact.familyName)".trimmingCharacters(in: .whitespaces)
                    : iCloudContact.organizationName
                
                let email = iCloudContact.emailAddresses.first?.value as String?
                let phone = iCloudContact.phoneNumbers.first?.value.stringValue
                
                let newCompany = CRMContact(
                    id: UUID(),
                    appleContactId: iCloudContact.identifier,
                    name: companyName,
                    email: email,
                    phone: phone,
                    isCompany: true,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                // Save the new company
                let savedCompany = try await repository.createContact(newCompany)
                
                // Update current contact with the company association
                var updatedContact = contact
                updatedContact.companyId = savedCompany.id
                updatedContact.company = savedCompany.name
                updatedContact.updatedAt = Date()
                
                let saved = try await repository.updateContact(updatedContact)
                
                await MainActor.run {
                    onSave(saved)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Company Row for Association Sheet

private struct CompanyRow: View {
    let company: CRMContact
    let isSaving: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Company icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }
                
                // Company info
                VStack(alignment: .leading, spacing: 2) {
                    Text(company.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let email = company.email {
                        Text(email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let phone = company.phone {
                        Text(phone)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }
}

// MARK: - iCloud Company Row

private struct ICloudCompanyRow: View {
    let contact: CNContact
    let isSaving: Bool
    let onSelect: () -> Void
    
    var displayName: String {
        if !contact.organizationName.isEmpty {
            return contact.organizationName
        }
        return "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
    }
    
    var subtitle: String? {
        if let email = contact.emailAddresses.first?.value as String? {
            return email
        }
        if let phone = contact.phoneNumbers.first?.value.stringValue {
            return phone
        }
        return nil
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // iCloud icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                
                // Contact info
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Will be imported as company")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }
}

// MARK: - Create Company Sheet

struct CreateCompanySheet: View {
    let onCompanyCreated: (CRMContact) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var domain = ""
    @State private var isSaving = false
    @State private var error: String?
    
    private let repository = ContactRepository()
    private let contactsManager = ContactsManager.shared
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("New Company")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    saveCompany()
                }
                .disabled(!canSave || isSaving)
            }
            .padding()
            
            Divider()
            
            Form {
                Section {
                    TextField("Company Name", text: $name)
                    TextField("Email (optional)", text: $email)
                    TextField("Phone (optional)", text: $phone)
                    TextField("Domain (optional)", text: $domain)
                }
                
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .padding()
            
            if isSaving {
                ProgressView("Creating company...")
                    .padding()
            }
        }
        .frame(width: 380, height: 320)
    }
    
    private func saveCompany() {
        guard canSave else { return }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEmail = email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedPhone = phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedDomain = domain.isEmpty ? nil : domain.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Create the company contact in Supabase
                let newCompany = CRMContact(
                    appleContactId: nil,
                    name: trimmedName,
                    email: trimmedEmail,
                    phone: trimmedPhone,
                    company: trimmedName,
                    domain: trimmedDomain,
                    isCompany: true
                )
                
                var created = try await repository.createContact(newCompany)
                print("CreateCompanySheet: Created company in Supabase with ID: \(created.id)")
                
                // Create matching contact in iCloud
                contactsManager.checkAuthorizationStatus()
                if contactsManager.authorizationStatus == .authorized {
                    do {
                        // For a company, we use the company name as firstName to make it display correctly
                        // and set the company field so organizationName is set
                        let appleContact = try await contactsManager.createContact(
                            firstName: trimmedName,
                            lastName: "",
                            email: trimmedEmail,
                            phone: trimmedPhone,
                            company: trimmedName  // This sets organizationName
                        )
                        
                        // Update the Supabase record with the Apple Contact ID
                        created.appleContactId = appleContact.identifier
                        created = try await repository.updateContact(created)
                        print("CreateCompanySheet: Linked to iCloud contact: \(appleContact.identifier)")
                    } catch {
                        print("CreateCompanySheet: Failed to create iCloud contact: \(error)")
                        // Continue anyway - company is saved in Supabase
                    }
                } else {
                    print("CreateCompanySheet: Contacts access not authorized - company will not sync to iCloud")
                }
                
                await MainActor.run {
                    onCompanyCreated(created)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to create company: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Associate Person Sheet

struct AssociatePersonSheet: View {
    let company: CRMContact
    let onAssociated: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var people: [CRMContact] = []
    @State private var iCloudContacts: [CNContact] = []
    @State private var isLoading = true
    @State private var isLoadingICloud = false
    @State private var isSaving = false
    @State private var selectedTab = 0
    @State private var error: String?
    @State private var showCreateContactSheet = false
    
    private let repository = ContactRepository()
    @ObservedObject private var contactsManager = ContactsManager.shared
    
    var filteredPeople: [CRMContact] {
        // Filter out people already associated with this company and companies
        let available = people.filter { $0.companyId != company.id && !$0.isCompany }
        
        if searchText.isEmpty {
            return available
        }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var filteredICloudContacts: [CNContact] {
        // Filter iCloud contacts that are individuals (not organizations)
        let individuals = iCloudContacts.filter { 
            !$0.givenName.isEmpty || !$0.familyName.isEmpty
        }
        
        if searchText.isEmpty {
            return individuals
        }
        return individuals.filter { 
            "\($0.givenName) \($0.familyName)".localizedCaseInsensitiveContains(searchText) ||
            $0.organizationName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Associate Person")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .opacity(0)
            }
            .padding()
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search people...", text: $searchText)
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
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Tab picker
            Picker("Source", selection: $selectedTab) {
                Text("Existing Contacts").tag(0)
                Text("iCloud Contacts").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Content
            if selectedTab == 0 {
                existingContactsTab
            } else {
                iCloudContactsTab
            }
        }
        .frame(width: 400, height: 550)
        .onAppear {
            loadPeople()
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == 1 && iCloudContacts.isEmpty {
                loadICloudContacts()
            }
        }
        .sheet(isPresented: $showCreateContactSheet) {
            CreatePersonForCompanySheet(company: company) {
                onAssociated()
                dismiss()
            }
        }
    }
    
    private var existingContactsTab: some View {
        Group {
            if isLoading {
                ProgressView("Loading contacts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Create New Contact button at the top
                        Button(action: { showCreateContactSheet = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Create New Contact")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text("Add a new person to \(company.name)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        if filteredPeople.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text(searchText.isEmpty ? "No contacts found" : "No matching contacts")
                                    .foregroundColor(.secondary)
                                Text("Create a new contact above, or import from iCloud")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(filteredPeople) { person in
                                Button(action: { associatePerson(person) }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.2))
                                                .frame(width: 44, height: 44)
                                            
                                            Text(person.initials)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.accentColor)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(person.name)
                                                .font(.body)
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
                                        
                                        if isSaving {
                                            ProgressView()
                                                .scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.title3)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .disabled(isSaving)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var iCloudContactsTab: some View {
        Group {
            if contactsManager.authorizationStatus != .authorized {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Contacts Access Required")
                        .font(.headline)
                    Text("Grant access to your contacts to import people from iCloud")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Grant Access") {
                        Task {
                            await contactsManager.requestAccess()
                            if contactsManager.authorizationStatus == .authorized {
                                loadICloudContacts()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoadingICloud {
                ProgressView("Loading iCloud contacts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredICloudContacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "icloud")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "No contacts in iCloud" : "No matching contacts")
                        .foregroundColor(.secondary)
                    Text("Your iCloud contacts will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredICloudContacts, id: \.identifier) { contact in
                            Button(action: { importAndAssociateFromICloud(contact) }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 44, height: 44)
                                        
                                        Text(iCloudInitials(for: contact))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(contact.givenName) \(contact.familyName)")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        if let email = contact.emailAddresses.first?.value as String? {
                                            Text(email)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else if let phone = contact.phoneNumbers.first?.value.stringValue {
                                            Text(phone)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if isSaving {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "icloud.and.arrow.down")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                }
                                .padding(10)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(isSaving)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func iCloudInitials(for contact: CNContact) -> String {
        let first = contact.givenName.prefix(1)
        let last = contact.familyName.prefix(1)
        return "\(first)\(last)".uppercased()
    }
    
    private func loadPeople() {
        isLoading = true
        Task {
            do {
                let allPeople = try await repository.fetchPeople()
                await MainActor.run {
                    self.people = allPeople
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load contacts: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadICloudContacts() {
        isLoadingICloud = true
        Task {
            do {
                let contacts = try await contactsManager.fetchAllContacts()
                await MainActor.run {
                    self.iCloudContacts = contacts
                    self.isLoadingICloud = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load iCloud contacts: \(error.localizedDescription)"
                    self.isLoadingICloud = false
                }
            }
        }
    }
    
    private func associatePerson(_ person: CRMContact) {
        isSaving = true
        
        Task {
            do {
                var updatedPerson = person
                updatedPerson.companyId = company.id
                updatedPerson.company = company.name
                updatedPerson.updatedAt = Date()
                
                // Inherit company's domain if person doesn't have one
                if (updatedPerson.domain == nil || updatedPerson.domain?.isEmpty == true),
                   let companyDomain = company.domain, !companyDomain.isEmpty {
                    updatedPerson.domain = companyDomain
                }
                
                _ = try await repository.updateContact(updatedPerson)
                
                await MainActor.run {
                    onAssociated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to associate: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
    
    private func importAndAssociateFromICloud(_ contact: CNContact) {
        isSaving = true
        
        Task {
            do {
                // Create new CRMContact from iCloud contact
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                let email = contact.emailAddresses.first?.value as String?
                let phone = contact.phoneNumbers.first?.value.stringValue
                
                var newContact = CRMContact(
                    appleContactId: contact.identifier,
                    name: name,
                    email: email,
                    phone: phone,
                    company: company.name,
                    domain: company.domain,
                    isCompany: false,
                    companyId: company.id,
                    createdAt: Date()
                )
                
                let created = try await repository.createContact(newContact)
                
                await MainActor.run {
                    onAssociated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to import: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Create Person For Company Sheet

struct CreatePersonForCompanySheet: View {
    let company: CRMContact
    let onCreated: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var isSaving = false
    @State private var error: String?
    
    private let repository = ContactRepository()
    private let contactsManager = ContactsManager.shared
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("New Contact")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    saveContact()
                }
                .disabled(!canSave || isSaving)
            }
            .padding()
            
            Divider()
            
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                    TextField("Phone", text: $phone)
                }
                
                Section {
                    HStack {
                        Text("Company")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(company.name)
                            .fontWeight(.medium)
                    }
                    
                    if let domain = company.domain {
                        HStack {
                            Text("Domain")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(domain)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .padding()
            
            if isSaving {
                ProgressView("Saving...")
                    .padding()
            }
        }
        .frame(width: 380, height: 350)
    }
    
    private func saveContact() {
        isSaving = true
        
        Task {
            do {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedEmail = email.isEmpty ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedPhone = phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Create in Supabase
                let newContact = CRMContact(
                    name: trimmedName,
                    email: trimmedEmail,
                    phone: trimmedPhone,
                    company: company.name,
                    domain: company.domain,
                    isCompany: false,
                    companyId: company.id,
                    createdAt: Date()
                )
                
                var created = try await repository.createContact(newContact)
                
                // Also create in iCloud if authorized
                contactsManager.checkAuthorizationStatus()
                if contactsManager.authorizationStatus == .authorized {
                    do {
                        let nameParts = trimmedName.components(separatedBy: " ")
                        let firstName = nameParts.first ?? trimmedName
                        let lastName = nameParts.dropFirst().joined(separator: " ")
                        
                        let appleContact = try await contactsManager.createContact(
                            firstName: firstName,
                            lastName: lastName,
                            email: trimmedEmail,
                            phone: trimmedPhone,
                            company: company.name
                        )
                        
                        // Update with Apple Contact ID
                        created.appleContactId = appleContact.identifier
                        _ = try await repository.updateContact(created)
                    } catch {
                        print("CreatePersonForCompanySheet: Failed to create iCloud contact: \(error)")
                    }
                }
                
                await MainActor.run {
                    onCreated()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to create contact: \(error.localizedDescription)"
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Label Pill View

struct LabelPillView: View {
    let label: ContactLabel
    var onRemove: (() -> Void)?
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label.name)
                .font(.caption)
                .fontWeight(.medium)
            
            if isHovered, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(label.swiftUIColor)
        .foregroundColor(.white)
        .cornerRadius(12)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Manage Labels Sheet

struct ManageLabelsSheet: View {
    @ObservedObject var viewModel: ContactDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showCreateLabel = false
    @State private var isCreatingLabel = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    private var filteredLabels: [ContactLabel] {
        if searchText.isEmpty {
            return viewModel.allLabels
        }
        return viewModel.allLabels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Manage Labels")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search labels...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Labels list
            if viewModel.isLoadingLabels {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredLabels.isEmpty {
                VStack(spacing: 16) {
                    Text("No labels found")
                        .foregroundColor(.secondary)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            showCreateLabel = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create '\(searchText)'")
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(filteredLabels) { label in
                            LabelRowView(
                                label: label,
                                isAssigned: viewModel.isLabelAssigned(label),
                                onToggle: { viewModel.toggleLabel(label) }
                            )
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Create new label button
            Button(action: { showCreateLabel = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create a new label")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .disabled(isCreatingLabel)
        }
        .frame(width: 350, height: 450)
        .overlay {
            if isCreatingLabel {
                Color.black.opacity(0.3)
                ProgressView("Creating label...")
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(10)
            }
        }
        .alert("Error Creating Label", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred. Please make sure you've run the Supabase migration SQL script.")
        }
        .sheet(isPresented: $showCreateLabel) {
            CreateLabelSheet(
                initialName: searchText,
                onCreate: { name, color in
                    createLabel(name: name, color: color)
                }
            )
        }
    }
    
    private func createLabel(name: String, color: String) {
        isCreatingLabel = true
        
        Task {
            do {
                _ = try await viewModel.createLabelAsync(name: name, color: color, assignToContact: true)
                await MainActor.run {
                    isCreatingLabel = false
                    searchText = ""
                }
            } catch {
                await MainActor.run {
                    isCreatingLabel = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                    print("ManageLabelsSheet: Failed to create label: \(error)")
                }
            }
        }
    }
}

// MARK: - Label Row View

struct LabelRowView: View {
    let label: ContactLabel
    let isAssigned: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isAssigned ? label.swiftUIColor : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isAssigned {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(label.swiftUIColor)
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Color bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(label.swiftUIColor)
                    .frame(width: 120, height: 28)
                    .overlay(
                        Text(label.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    )
                
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Create Label Sheet

struct CreateLabelSheet: View {
    var initialName: String = ""
    let onCreate: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColor: String = "#42A5F5"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Label")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 20) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Label Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Enter label name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Color palette
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // Color grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                        ForEach(ContactLabel.colorPalette, id: \.hex) { colorOption in
                            ColorOptionView(
                                color: colorOption.hex,
                                isSelected: selectedColor == colorOption.hex,
                                onSelect: { selectedColor = colorOption.hex }
                            )
                        }
                    }
                }
                
                // Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        LabelPillView(label: ContactLabel(name: name, color: selectedColor))
                    } else {
                        Text("Enter a name to see preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            
            Spacer()
            
            Divider()
            
            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    let trimmedName = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmedName.isEmpty else { return }
                    onCreate(trimmedName, selectedColor)
                    dismiss()
                }) {
                    Text("Create")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .onAppear {
            name = initialName
        }
    }
}

// MARK: - Color Option View

struct ColorOptionView: View {
    let color: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: color) ?? .blue)
                    .frame(width: 40, height: 40)
                
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
