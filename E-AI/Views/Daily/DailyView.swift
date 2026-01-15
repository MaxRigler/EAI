// DailyView.swift
// Calendar-based view of all activity by day

import SwiftUI

struct DailyView: View {
    @StateObject private var viewModel = DailyViewModel()
    @ObservedObject private var recorderViewModel = RecorderViewModel.shared
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Compact recorder at top
            CompactRecorderView()
            
            Divider()
            
            // Date navigation
            dateNavigation
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // AI-generated daily brief or generate button
                    if let summary = viewModel.dailySummary {
                        dailyBriefCard(summary)
                    } else if !viewModel.recordings.isEmpty {
                        generateSummaryCard
                    }
                    
                    // Recordings list
                    recordingsList
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.loadDay()
        }
    }
    
    // MARK: - Date Navigation
    
    private var dateNavigation: some View {
        HStack {
            Button(action: { viewModel.goToPreviousDay() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Date display with picker popover
            Button(action: { showDatePicker.toggle() }) {
                VStack(spacing: 2) {
                    Text(viewModel.selectedDate.formatted(date: .complete, time: .omitted))
                        .font(.headline)
                    
                    if Calendar.current.isDateInToday(viewModel.selectedDate) {
                        Text("Today")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDatePicker) {
                VStack(spacing: 12) {
                    DatePicker(
                        "Select Date",
                        selection: Binding(
                            get: { viewModel.selectedDate },
                            set: { newDate in
                                viewModel.selectedDate = newDate
                                viewModel.loadDay()
                                showDatePicker = false
                            }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .frame(width: 280, height: 280)
                    
                    Button("Today") {
                        viewModel.goToToday()
                        showDatePicker = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            
            Spacer()
            
            // Today button (only show if not already on today)
            if !Calendar.current.isDateInToday(viewModel.selectedDate) {
                Button(action: { viewModel.goToToday() }) {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: { viewModel.goToNextDay() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(Calendar.current.isDateInToday(viewModel.selectedDate))
        }
        .padding()
    }
    
    // MARK: - Generate Summary Card
    
    private var generateSummaryCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            
            Text("No Daily Brief Yet")
                .font(.headline)
            
            Text("Generate an AI summary of today's \(viewModel.recordings.count) recording\(viewModel.recordings.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { viewModel.generateDailySummary() }) {
                HStack {
                    if viewModel.isGeneratingSummary {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(viewModel.isGeneratingSummary ? "Generating..." : "Generate Daily Brief")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isGeneratingSummary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Daily Brief Card
    
    private func dailyBriefCard(_ summary: DailySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text("Daily Brief")
                    .font(.headline)
                Spacer()
                
                // Regenerate button
                Button(action: { viewModel.generateDailySummary() }) {
                    if viewModel.isGeneratingSummary {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .disabled(viewModel.isGeneratingSummary)
                .help("Regenerate Daily Brief")
            }
            
            MarkdownText(text: summary.summaryText)
                .font(.body)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            
            // Stats
            HStack(spacing: 16) {
                StatBadge(icon: "mic.fill", value: "\(summary.recordingCount)", label: "Calls")
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Recordings List
    
    private var recordingsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recordings")
                .font(.headline)
            
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.recordings.isEmpty {
                emptyRecordingsState
            } else {
                ForEach(viewModel.recordings) { recording in
                    RecordingCard(recording: recording, onContactAdded: {
                        viewModel.loadDay()
                    })
                }
            }
        }
    }
    
    private var emptyRecordingsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No recordings on this day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Recording Card

struct RecordingCard: View {
    let recording: Recording
    var onContactAdded: (() -> Void)? = nil
    
    @State private var isExpanded = false
    @State private var showAddContactSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Recording Type + Status + Duration + Time
            HStack(spacing: 8) {
                // Recording type badge
                if let typeName = recording.recordingTypeName {
                    Text(typeName)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
                
                // Processing status indicator
                processingStatusBadge
                
                Spacer()
                
                // Duration
                Text(recording.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Time
                Text(recording.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Contact badges row (horizontal scrollable)
            // Deduplicate companies: collect unique companies first, then show individuals
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // First, collect unique companies (from both direct company contacts and individual contacts' companies)
                    let uniqueCompanies: [CRMContact] = {
                        var seen = Set<UUID>()
                        var companies: [CRMContact] = []
                        for contact in recording.contacts {
                            // Add company contacts that are directly speakers
                            if contact.isCompany && !seen.contains(contact.id) {
                                seen.insert(contact.id)
                                companies.append(contact)
                            }
                            // Add companies associated with individual contacts
                            if let company = contact.companyContact, !seen.contains(company.id) {
                                seen.insert(company.id)
                                companies.append(company)
                            }
                        }
                        return companies
                    }()
                    
                    // Collect individual (non-company) contacts
                    let individuals = recording.contacts.filter { !$0.isCompany }
                    
                    // Display company badges first (teal with building icon)
                    ForEach(uniqueCompanies, id: \.id) { company in
                        Button(action: {
                            AppNavigationState.shared.navigateToContact(company)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.caption2)
                                Text(company.name)
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Display individual contacts (orange)
                    ForEach(individuals, id: \.id) { contact in
                        Button(action: {
                            AppNavigationState.shared.navigateToContact(contact)
                        }) {
                            Text(contact.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Add contact button
                    Button(action: { showAddContactSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Add contact to recording")
                }
            }
            
            // Status detail for in-progress or failed states
            if recording.status != .complete {
                statusDetailRow
            }
            
            // Summary section (expandable when complete)
            if recording.status == .complete, let summary = recording.summaryPreview {
                VStack(alignment: .leading, spacing: 4) {
                    // Summary text - expandable, selectable, with markdown rendering
                    MarkdownText(text: isExpanded ? (recording.fullSummary ?? summary) : summary)
                        .lineLimit(isExpanded ? nil : 2)
                        .textSelection(.enabled)
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    
                    // Expand/Collapse button
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
            
            // Error message if failed
            if recording.status == .failed, let errorMsg = recording.errorMessage {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(statusBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusBorderColor, lineWidth: recording.status == .failed ? 1 : 0)
        )
        .sheet(isPresented: $showAddContactSheet) {
            AddContactToRecordingSheet(recording: recording) {
                onContactAdded?()
            }
        }
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var processingStatusBadge: some View {
        switch recording.status {
        case .processing:
            statusBadge(icon: "arrow.clockwise", text: "Queued", color: .orange, spinning: true)
        case .transcribing:
            statusBadge(icon: "waveform", text: "Transcribing", color: .blue, spinning: true)
        case .summarizing:
            statusBadge(icon: "sparkles", text: "Summarizing", color: .purple, spinning: true)
        case .complete:
            statusBadge(icon: "checkmark.circle.fill", text: nil, color: .green, spinning: false)
        case .failed:
            statusBadge(icon: "exclamationmark.triangle.fill", text: "Failed", color: .red, spinning: false)
        }
    }
    
    private func statusBadge(icon: String, text: String?, color: Color, spinning: Bool) -> some View {
        HStack(spacing: 4) {
            if spinning {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: icon)
                    .font(.caption2)
            }
            
            if let text = text {
                Text(text)
                    .font(.caption2)
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .cornerRadius(6)
    }
    
    // MARK: - Status Detail Row
    
    private var statusDetailRow: some View {
        HStack(spacing: 6) {
            switch recording.status {
            case .processing:
                Image(systemName: "clock")
                    .font(.caption)
                Text("Waiting in queue...")
            case .transcribing:
                Image(systemName: "waveform")
                    .font(.caption)
                Text("Converting speech to text...")
            case .summarizing:
                Image(systemName: "text.alignleft")
                    .font(.caption)
                Text("Generating summary...")
            case .failed:
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
                Text("Retry \(recording.retryCount)/3")
            case .complete:
                EmptyView()
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    // MARK: - Colors
    
    private var statusBackgroundColor: Color {
        switch recording.status {
        case .failed:
            return Color.red.opacity(0.05)
        case .complete:
            return Color(NSColor.controlBackgroundColor)
        default:
            return Color(NSColor.controlBackgroundColor)
        }
    }
    
    private var statusBorderColor: Color {
        recording.status == .failed ? Color.red.opacity(0.3) : .clear
    }
}

// MARK: - Markdown Text View

/// A view that renders markdown-formatted text with proper styling
struct MarkdownText: View {
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
        var trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
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
                    beforeAttr.font = .body
                    result.append(beforeAttr)
                }
                
                // Find the closing **
                let afterStart = remaining[boldStart.upperBound...]
                if let boldEnd = afterStart.range(of: "**") {
                    let boldContent = String(afterStart[..<boldEnd.lowerBound])
                    var boldAttr = AttributedString(boldContent)
                    boldAttr.font = .body.bold()
                    result.append(boldAttr)
                    
                    remaining = String(afterStart[boldEnd.upperBound...])
                } else {
                    // No closing **, treat as regular text
                    var attr = AttributedString(String(remaining))
                    attr.font = .body
                    result.append(attr)
                    remaining = ""
                }
            } else {
                // No more bold markers
                var attr = AttributedString(remaining)
                attr.font = .body
                result.append(attr)
                remaining = ""
            }
        }
        
        return result
    }
}

// MARK: - Add Contact to Recording Sheet

struct AddContactToRecordingSheet: View {
    let recording: Recording
    let onContactAdded: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var contacts: [CRMContact] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    
    private let contactRepository = ContactRepository()
    private let recordingRepository = RecordingRepository()
    
    var filteredContacts: [CRMContact] {
        let existingContactIds = Set(recording.contacts.map { $0.id })
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
                    Text(searchText.isEmpty ? "All contacts already associated" : "No matching contacts")
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
            loadContacts()
        }
    }
    
    private func loadContacts() {
        isLoading = true
        Task {
            do {
                let allContacts = try await contactRepository.fetchAllContacts()
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
    
    private func addContact(_ contact: CRMContact) {
        isSaving = true
        error = nil
        
        Task {
            do {
                // Get existing speakers to determine next speaker number
                let existingSpeakers = try await recordingRepository.fetchRecordingSpeakers(recordingId: recording.id)
                let nextSpeakerNumber = (existingSpeakers.map { $0.speakerNumber }.max() ?? 0) + 1
                
                // Create new speaker
                let speaker = RecordingSpeaker(
                    id: UUID(),
                    recordingId: recording.id,
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
    DailyView()
        .frame(width: 390, height: 700)
}
