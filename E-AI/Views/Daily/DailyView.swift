// DailyView.swift
// Calendar-based view of all activity by day

import SwiftUI

struct DailyView: View {
    @StateObject private var viewModel = DailyViewModel()
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(spacing: 0) {
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
                    RecordingCard(recording: recording)
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
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: Contact Name Badge + Recording Type Badge + Status + Time
            HStack(spacing: 8) {
                // Contact badges: show company first, then individual contact
                ForEach(recording.contacts, id: \.id) { contact in
                    // If contact has a company association, show BOTH company and rep badge
                    if let company = contact.companyContact {
                        // Company badge (teal)
                        Button(action: {
                            AppNavigationState.shared.navigateToContact(company)
                        }) {
                            Text(company.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.teal)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        // Rep badge (orange to distinguish)
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
                    } else {
                        // No company association, just show contact badge (teal)
                        Button(action: {
                            AppNavigationState.shared.navigateToContact(contact)
                        }) {
                            HStack(spacing: 4) {
                                if contact.isCompany {
                                    Image(systemName: "building.2.fill")
                                        .font(.caption2)
                                }
                                Text(contact.name)
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
                }
                
                // Recording type badge (accent/purple color)
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

#Preview {
    DailyView()
        .frame(width: 390, height: 700)
}
