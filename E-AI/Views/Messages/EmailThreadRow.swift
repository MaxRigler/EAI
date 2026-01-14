// EmailThreadRow.swift
// Row component for displaying an email thread in the list

import SwiftUI

struct EmailThreadRow: View {
    let thread: EmailThread
    let isExpanded: Bool
    let isArchived: Bool
    let onTap: () -> Void
    let onArchive: () -> Void
    let onRemind: ((Date, String?) -> Void)?  // (date, context)
    let onReply: ((String) async throws -> Void)?
    let onCompanyTap: ((CRMContact) -> Void)?
    
    @State private var isHovering = false
    @State private var showReplyComposer = false
    @State private var showReminderPicker = false
    @State private var showContextPopover = false
    @State private var replyText = ""
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(thread: EmailThread,
         isExpanded: Bool,
         isArchived: Bool,
         onTap: @escaping () -> Void,
         onArchive: @escaping () -> Void,
         onRemind: ((Date, String?) -> Void)? = nil,
         onReply: ((String) async throws -> Void)? = nil,
         onCompanyTap: ((CRMContact) -> Void)? = nil) {
        self.thread = thread
        self.isExpanded = isExpanded
        self.isArchived = isArchived
        self.onTap = onTap
        self.onArchive = onArchive
        self.onRemind = onRemind
        self.onReply = onReply
        self.onCompanyTap = onCompanyTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main thread row
            HStack(spacing: 0) {
                // Action buttons (visible on hover, hidden when expanded)
                if isHovering && !isExpanded {
                    Group {
                        if isArchived {
                            // Single unarchive button when archived
                            Button(action: onArchive) {
                                VStack(spacing: 4) {
                                    Image(systemName: "tray.and.arrow.up.fill")
                                        .font(.system(size: 16))
                                    Text("Unarchive")
                                        .font(.system(size: 9))
                                }
                                .foregroundColor(.white)
                                .frame(width: 70)
                                .frame(maxHeight: .infinity)
                                .background(Color.blue)
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Split button: Archive (top) and Remind (bottom)
                            VStack(spacing: 0) {
                                Button(action: onArchive) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "archivebox.fill")
                                            .font(.system(size: 14))
                                        Text("Archive")
                                            .font(.system(size: 8))
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 70)
                                    .frame(maxHeight: .infinity)
                                    .background(Color.orange)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { showReminderPicker = true }) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 14))
                                        Text("Remind")
                                            .font(.system(size: 8))
                                    }
                                    .foregroundColor(.white)
                                    .frame(width: 70)
                                    .frame(maxHeight: .infinity)
                                    .background(Color.purple)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                
                // Main content
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        // Avatar/initials
                        avatar
                        
                        // Content
                        VStack(alignment: .leading, spacing: 4) {
                            // Top row: sender + message count + timestamp
                            HStack {
                                Text(thread.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                // Message count badge
                                if thread.messages.count > 1 {
                                    Text("\(thread.messages.count)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary)
                                        .clipShape(Capsule())
                                }
                                
                                Spacer()
                                
                                Text(formattedTimestamp)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Subject line
                            HStack(spacing: 6) {
                                // Direction indicator
                                directionIndicator
                                
                                Text(thread.subject)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                            
                            // Snippet preview
                            Text(thread.snippet)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            // Badges row
                            HStack(spacing: 8) {
                                // Company association badge
                                if let companyContact = thread.companyContact {
                                    Button(action: {
                                        onCompanyTap?(companyContact)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "building.2.fill")
                                                .font(.system(size: 10))
                                            Text(companyContact.name)
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Scheduled reminder indicator (clickable to show context)
                                if let reminderDate = thread.reminderDate {
                                    Button(action: { showContextPopover = true }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bell.fill")
                                                .font(.system(size: 10))
                                            Text("Returns \(formatReminderDate(reminderDate))")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                    .popover(isPresented: $showContextPopover) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Reminder Context")
                                                .font(.headline)
                                            Divider()
                                            if let context = thread.reminderContext, !context.isEmpty {
                                                Text(context)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                            } else {
                                                Text("No context notes added")
                                                    .font(.body)
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                            }
                                        }
                                        .padding()
                                        .frame(minWidth: 200, maxWidth: 300)
                                    }
                                }
                            }
                        }
                        
                        // Expand indicator
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                }
                .buttonStyle(.plain)
            }
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            
            // Expanded thread messages
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(thread.messages, id: \.id) { email in
                        EmailMessageRow(email: email)
                    }
                    
                    // Reply section
                    replySection
                }
                .padding(.leading, 48)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        // Right-click context menu as alternative
        .contextMenu {
            Button(action: onArchive) {
                Label(
                    isArchived ? "Unarchive" : "Archive",
                    systemImage: isArchived ? "tray.and.arrow.up" : "archivebox"
                )
            }
            
            if !isArchived {
                Button(action: { showReminderPicker = true }) {
                    Label("Remind Me", systemImage: "bell")
                }
            }
        }
        .alert("Error Sending Reply", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showReminderPicker) {
            ReminderPickerSheet(
                threadSubject: thread.subject,
                onSelect: { date, context in
                    onRemind?(date, context)
                    showReminderPicker = false
                },
                onCancel: {
                    showReminderPicker = false
                }
            )
        }
    }
    
    // MARK: - Reply Section
    
    @ViewBuilder
    private var replySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)
            
            // Reply button that opens sheet
            Button(action: { showReplyComposer = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 12))
                    Text("Reply")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showReplyComposer) {
            ReplyComposerSheet(
                recipientName: thread.displayName,
                recipientEmail: thread.recipientEmail,
                subject: thread.subject,
                onSend: { text, cc, bcc in
                    replyText = text
                    // TODO: Pass CC/BCC to the reply function
                    sendReply()
                },
                onCancel: {
                    showReplyComposer = false
                }
            )
        }
    }
    
    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func sendReply() {
        guard canSend, let onReply = onReply else { return }
        
        isSending = true
        
        Task {
            do {
                try await onReply(replyText.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    isSending = false
                    replyText = ""
                    showReplyComposer = false
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
    
    // MARK: - Avatar
    
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Text(avatarInitials)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
        }
    }
    
    private var avatarInitials: String {
        let name = thread.displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    private func formatReminderDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "tomorrow at \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Direction Indicator
    
    @ViewBuilder
    private var directionIndicator: some View {
        let direction = thread.latestMessage.direction
        
        HStack(spacing: 2) {
            Image(systemName: direction == .inbound ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 8))
            Text(direction == .inbound ? "In" : "Out")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(direction == .inbound ? .blue : .green)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (direction == .inbound ? Color.blue : Color.green).opacity(0.15)
        )
        .cornerRadius(4)
    }
    
    // MARK: - Formatting
    
    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(thread.timestamp) {
            return thread.timestamp.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(thread.timestamp) {
            return "Yesterday"
        } else if calendar.isDate(thread.timestamp, equalTo: now, toGranularity: .weekOfYear) {
            return thread.timestamp.formatted(.dateTime.weekday(.abbreviated))
        } else {
            return thread.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Email Message Row (for expanded view)

struct EmailMessageRow: View {
    let email: Email
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Direction badge
                directionBadge
                
                Text(email.direction == .inbound ? (email.senderName ?? email.senderEmail ?? "Unknown") : "You")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(email.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Subject (if different from thread)
            if let subject = email.subject, !subject.isEmpty {
                Text(subject)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Body preview or full
            if let body = email.body {
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 3)
                
                if body.count > 150 {
                    Button(action: { isExpanded.toggle() }) {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundColor(email.direction == .inbound ? .blue : .green)
                .opacity(0.5),
            alignment: .leading
        )
    }
    
    private var directionBadge: some View {
        Image(systemName: email.direction == .inbound ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
            .font(.caption)
            .foregroundColor(email.direction == .inbound ? .blue : .green)
    }
}

#Preview {
    VStack {
        EmailThreadRow(
            thread: EmailThread(
                id: "1",
                subject: "Re: Project Update",
                participants: ["John Doe", "Jane Smith"],
                latestMessage: Email(
                    contactId: UUID(),
                    gmailId: "123",
                    threadId: "1",
                    subject: "Re: Project Update",
                    body: "Thanks for the update! Everything looks good.",
                    direction: .inbound,
                    timestamp: Date(),
                    senderEmail: "john@example.com",
                    senderName: "John Doe"
                ),
                messages: [],
                unreadCount: 0,
                isArchived: false,
                reminderDate: nil,
                reminderContext: nil,
                contact: nil,
                companyContact: nil
            ),
            isExpanded: true,
            isArchived: false,
            onTap: {},
            onArchive: {},
            onReply: { _ in }
        )
    }
    .padding()
    .frame(width: 380)
}

// MARK: - Native macOS Text View

/// A native macOS text view that properly handles click and keyboard input
struct MacOSTextView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.textColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        
        // Very important for editability
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        scrollView.documentView = textView
        
        // Store reference in coordinator
        context.coordinator.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Only update if different (prevents cursor jumping)
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacOSTextView
        weak var textView: NSTextView?
        
        init(_ parent: MacOSTextView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Reply Composer Sheet

struct ReplyComposerSheet: View {
    let recipientName: String
    let recipientEmail: String
    let subject: String
    let onSend: (String, [String], [String]) -> Void  // body, cc, bcc
    let onCancel: () -> Void
    
    @State private var messageText = ""
    @State private var ccText = ""
    @State private var bccText = ""
    @State private var showCc = false
    @State private var showBcc = false
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss
    
    init(recipientName: String, 
         recipientEmail: String = "",
         subject: String, 
         onSend: @escaping (String, [String], [String]) -> Void, 
         onCancel: @escaping () -> Void) {
        self.recipientName = recipientName
        self.recipientEmail = recipientEmail
        self.subject = subject
        self.onSend = onSend
        self.onCancel = onCancel
    }
    
    // For backward compatibility
    init(recipientName: String, 
         subject: String, 
         onSend: @escaping (String) -> Void, 
         onCancel: @escaping () -> Void) {
        self.recipientName = recipientName
        self.recipientEmail = ""
        self.subject = subject
        self.onSend = { body, _, _ in onSend(body) }
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("Reply")
                    .font(.headline)
                
                Spacer()
                
                Button(action: send) {
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
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // To field
                    HStack(alignment: .top) {
                        Text("To:")
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        // Recipient chip
                        HStack(spacing: 4) {
                            Text(recipientName)
                                .fontWeight(.medium)
                            if !recipientEmail.isEmpty {
                                Text("<\(recipientEmail)>")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                        
                        Spacer()
                        
                        // Cc/Bcc toggle
                        if !showCc || !showBcc {
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
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    // Cc field
                    if showCc {
                        Divider()
                            .padding(.leading, 50)
                        
                        HStack(alignment: .center) {
                            Text("Cc:")
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            
                            TextField("Add recipients", text: $ccText)
                                .textFieldStyle(.plain)
                                .font(.body)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // Bcc field
                    if showBcc {
                        Divider()
                            .padding(.leading, 50)
                        
                        HStack(alignment: .center) {
                            Text("Bcc:")
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            
                            TextField("Add recipients", text: $bccText)
                                .textFieldStyle(.plain)
                                .font(.body)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    // Subject
                    HStack {
                        Text("Subject:")
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        Text("Re: \(subject)")
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Message body
                    TextEditor(text: $messageText)
                        .font(.body)
                        .frame(minHeight: 180)
                        .padding(4)
                }
            }
        }
        .frame(width: 450, height: 400)
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func send() {
        guard canSend else { return }
        isSending = true
        
        // Parse CC and BCC into arrays
        let ccRecipients = parseEmails(ccText)
        let bccRecipients = parseEmails(bccText)
        
        onSend(messageText, ccRecipients, bccRecipients)
        dismiss()
    }
    
    private func parseEmails(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return text
            .components(separatedBy: CharacterSet(charactersIn: ",;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Reminder Picker Sheet

struct ReminderPickerSheet: View {
    let threadSubject: String
    let onSelect: (Date, String?) -> Void  // (date, context)
    let onCancel: () -> Void
    
    @State private var selectedDate = Date().addingTimeInterval(3600) // Default: 1 hour from now
    @State private var selectedPreset: ReminderPreset? = nil
    @State private var contextText = ""
    @Environment(\.dismiss) private var dismiss
    
    enum ReminderPreset: String, CaseIterable {
        case laterToday = "Later Today"
        case tomorrow = "Tomorrow"
        case nextWeek = "Next Week"
        case custom = "Custom..."
        
        func date() -> Date {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .laterToday:
                // 3 hours from now, or 6 PM today, whichever is later
                let threeHours = now.addingTimeInterval(3 * 3600)
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = 18
                components.minute = 0
                let sixPM = calendar.date(from: components) ?? threeHours
                return max(threeHours, sixPM)
                
            case .tomorrow:
                // 8 AM tomorrow
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.day! += 1
                components.hour = 8
                components.minute = 0
                return calendar.date(from: components) ?? now.addingTimeInterval(24 * 3600)
                
            case .nextWeek:
                // Next Monday at 8 AM
                var components = calendar.dateComponents([.year, .month, .day, .weekday], from: now)
                let daysUntilMonday = (9 - (components.weekday ?? 1)) % 7
                components.day! += daysUntilMonday == 0 ? 7 : daysUntilMonday
                components.hour = 8
                components.minute = 0
                components.weekday = nil
                return calendar.date(from: components) ?? now.addingTimeInterval(7 * 24 * 3600)
                
            case .custom:
                return now.addingTimeInterval(3600)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("Remind Me")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    let context = contextText.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSelect(selectedDate, context.isEmpty ? nil : context)
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .fontWeight(.semibold)
            }
            .padding()
            
            Divider()
            
            // Subject preview
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.secondary)
                Text(threadSubject)
                    .lineLimit(1)
                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            
            // Quick presets
            VStack(spacing: 0) {
                ForEach(ReminderPreset.allCases, id: \.self) { preset in
                    Button(action: {
                        if preset == .custom {
                            selectedPreset = .custom
                        } else {
                            selectedDate = preset.date()
                            selectedPreset = preset
                        }
                    }) {
                        HStack {
                            Image(systemName: iconFor(preset))
                                .frame(width: 24)
                                .foregroundColor(colorFor(preset))
                            
                            Text(preset.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if preset != .custom {
                                Text(formatPresetDate(preset.date()))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            if selectedPreset == preset {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    if preset != .custom {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            
            // Custom date picker (shown when custom is selected)
            if selectedPreset == .custom {
                Divider()
                
                DatePicker(
                    "Remind at:",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            
            // Context text field
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                
                Text("Add context (optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                TextField("e.g., Max on vacation until Jan 27", text: $contextText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            
            Spacer()
        }
        .frame(width: 350, height: selectedPreset == .custom ? 560 : 420)
    }
    
    private func iconFor(_ preset: ReminderPreset) -> String {
        switch preset {
        case .laterToday: return "sun.max.fill"
        case .tomorrow: return "sunrise.fill"
        case .nextWeek: return "calendar"
        case .custom: return "clock"
        }
    }
    
    private func colorFor(_ preset: ReminderPreset) -> Color {
        switch preset {
        case .laterToday: return .orange
        case .tomorrow: return .yellow
        case .nextWeek: return .blue
        case .custom: return .purple
        }
    }
    
    private func formatPresetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}
