// RecorderView.swift
// Primary recording interface

import SwiftUI
import Contacts

struct RecorderView: View {
    @ObservedObject private var viewModel = RecorderViewModel.shared
    @State private var showRecordingTypeSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Recording status indicator
            recordingIndicator
            
            // Timer display
            timerDisplay
            
            // Record/Stop button
            recordButton
            
            Spacer()
            
            // Audio input selector with system audio status
            audioInputSection
            
            // Recording type selector
            recordingTypeSection
            
            // Speaker assignment (shown when recording or has unprocessed)
            if viewModel.isRecording || viewModel.hasUnprocessedRecording {
                speakerAssignmentSection
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showRecordingTypeSheet) {
            RecordingTypeSheet(selectedType: $viewModel.selectedRecordingType)
        }
        .sheet(isPresented: $viewModel.showStopRecordingModal) {
            ConfirmAndSaveView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadRecordingTypes()
        }
    }
    
    // MARK: - Recording Indicator
    
    private var recordingIndicator: some View {
        ZStack {
            Circle()
                .stroke(viewModel.isRecording ? Color.red.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 4)
                .frame(width: 120, height: 120)
            
            if viewModel.isRecording {
                Circle()
                    .stroke(Color.red, lineWidth: 4)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 2)
                            .scaleEffect(CGFloat(viewModel.audioLevel) * 0.5 + 1.0)
                            .opacity(0.7)
                    )
                    .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
            }
            
            Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 40))
                .foregroundColor(viewModel.isRecording ? .red : .secondary)
        }
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        Text(viewModel.formattedDuration)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundColor(viewModel.isRecording ? .primary : .secondary)
    }
    
    // MARK: - Record Button
    
    private var recordButton: some View {
        Button(action: {
            if viewModel.isRecording {
                viewModel.stopRecording()
            } else {
                viewModel.startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.accentColor)
                    .frame(width: 72, height: 72)
                    .shadow(color: (viewModel.isRecording ? Color.red : Color.accentColor).opacity(0.4), radius: 8, y: 4)
                
                if viewModel.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .help(viewModel.isRecording ? "Stop Recording" : "Start Recording")
    }
    
    // MARK: - Audio Input Section
    
    private var audioInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio Input")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                // Microphone dropdown
                Menu {
                    ForEach(viewModel.availableInputs, id: \.uniqueID) { device in
                        Button(device.localizedName) {
                            viewModel.selectInput(device)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.secondary)
                        Text(viewModel.selectedInput?.localizedName ?? "Select Input")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // System audio status badge
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(viewModel.isSystemAudioEnabled ? .green : .orange)
                    Text(viewModel.isSystemAudioEnabled ? "System: On" : "System: Off")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(viewModel.isSystemAudioEnabled ? .green : .orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    viewModel.isSystemAudioEnabled 
                        ? Color.green.opacity(0.15)
                        : Color.orange.opacity(0.15)
                )
                .cornerRadius(6)
                .help(viewModel.isSystemAudioEnabled 
                    ? "System audio capture is active - other participants will be recorded" 
                    : "System audio capture is off - only your microphone is recording")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Recording Type Section
    
    private var recordingTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recording Type")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: { showRecordingTypeSheet = true }) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.secondary)
                    Text(viewModel.selectedRecordingType?.name ?? "Select Type")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Speaker Assignment Section
    
    private var speakerAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speakers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Add speaker button
                if viewModel.canAddSpeaker {
                    Button(action: { viewModel.addSpeaker() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add")
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            VStack(spacing: 6) {
                ForEach(viewModel.activeSpeakers, id: \.self) { speakerNum in
                    SpeakerRow(
                        speakerNumber: speakerNum,
                        assignedContact: viewModel.speakerAssignments[speakerNum],
                        isUser: speakerNum == 1,
                        canRemove: speakerNum != 1,
                        onAssign: { contact in
                            viewModel.assignSpeaker(speakerNum, to: contact)
                        },
                        onRemove: {
                            viewModel.removeSpeaker(speakerNum)
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Speaker Row

struct SpeakerRow: View {
    let speakerNumber: Int
    let assignedContact: CRMContact?
    let isUser: Bool
    let canRemove: Bool
    let onAssign: (CRMContact?) -> Void
    let onRemove: () -> Void
    
    @State private var showContactPicker = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Remove button (for non-user speakers)
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            
            Text("Speaker \(speakerNumber)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: canRemove ? 60 : 70, alignment: .leading)
            
            Button(action: { showContactPicker = true }) {
                HStack {
                    if isUser {
                        Image(systemName: "person.fill")
                            .foregroundColor(.accentColor)
                        Text("Me")
                    } else if let contact = assignedContact {
                        Image(systemName: "person.fill")
                            .foregroundColor(.green)
                        Text(contact.name)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.secondary)
                        Text("Assign")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(isUser)
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerSheet(onSelect: onAssign)
        }
    }
}

// MARK: - Recording Type Sheet

struct RecordingTypeSheet: View {
    @Binding var selectedType: RecordingType?
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = RecordingTypesViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recording Type")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            
            Divider()
            
            // Type list with loading state
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if viewModel.recordingTypes.isEmpty {
                Spacer()
                Text("No recording types found")
                    .foregroundColor(.secondary)
                Text("Add types in Settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(viewModel.recordingTypes) { type in
                    Button(action: {
                        selectedType = type
                        dismiss()
                    }) {
                        HStack {
                            Text(type.name)
                            Spacer()
                            if selectedType?.id == type.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 300, height: 400)
        .onAppear {
            viewModel.loadRecordingTypes()
        }
    }
}


// MARK: - Contact Picker Sheet

struct ContactPickerSheet: View {
    let onSelect: (CRMContact?) -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var crmViewModel = ContactsViewModel()
    @StateObject private var appleContactsManager = ContactsManager.shared
    @State private var searchText = ""
    @State private var showCreateContact = false
    @State private var selectedTab = 0 // 0 = Business, 1 = Apple Contacts
    @State private var appleContacts: [CNContact] = []
    @State private var isLoadingApple = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Contact")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()
            
            // Tab picker
            Picker("Contact Source", selection: $selectedTab) {
                Text("Business").tag(0)
                Text("Apple Contacts").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Search
            TextField("Search contacts...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: searchText) { newValue in
                    if selectedTab == 0 {
                        crmViewModel.search(query: newValue)
                    } else {
                        searchAppleContacts(newValue)
                    }
                }
            
            Divider()
                .padding(.top, 8)
            
            // Content based on selected tab
            if selectedTab == 0 {
                businessContactsList
            } else {
                appleContactsList
            }
            
            Divider()
            
            // Create new contact option
            Button(action: { showCreateContact = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Create New Contact")
                }
            }
            .buttonStyle(.plain)
            .padding()
        }
        .frame(width: 320, height: 500)
        .onAppear {
            crmViewModel.loadContacts()
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 1 {
                loadAppleContacts()
            }
        }
        .sheet(isPresented: $showCreateContact) {
            CreateContactSheet { newContact in
                onSelect(newContact)
                dismiss()
            }
        }
    }
    
    // MARK: - Business Contacts List
    
    private var businessContactsList: some View {
        Group {
            if crmViewModel.isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if crmViewModel.filteredContacts.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No business contacts")
                        .foregroundColor(.secondary)
                    Text("Create one or check Apple Contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(crmViewModel.filteredContacts) { contact in
                    Button(action: {
                        onSelect(contact)
                        dismiss()
                    }) {
                        ContactRowView(name: contact.name, company: contact.company, isBusinessContact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Apple Contacts List
    
    private var appleContactsList: some View {
        Group {
            switch appleContactsManager.authorizationStatus {
            case .notDetermined:
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Access Required")
                        .font(.headline)
                    Text("Grant permission to access your Apple Contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Request Access") {
                        requestAppleContactsAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
                
            case .denied, .restricted:
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Access Denied")
                        .font(.headline)
                    Text("Enable Contacts access in System Settings → Privacy → Contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
                
            case .authorized:
                if isLoadingApple {
                    Spacer()
                    ProgressView("Loading contacts...")
                    Spacer()
                } else if appleContacts.isEmpty {
                    Spacer()
                    Text("No contacts found")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(filteredAppleContacts, id: \.identifier) { contact in
                        Button(action: {
                            selectAppleContact(contact)
                        }) {
                            ContactRowView(
                                name: contact.fullName,
                                company: contact.organizationName.isEmpty ? nil : contact.organizationName,
                                isBusinessContact: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
            @unknown default:
                Spacer()
                Text("Unknown authorization status")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
    
    private var filteredAppleContacts: [CNContact] {
        if searchText.isEmpty {
            return appleContacts
        }
        return appleContacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            $0.organizationName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    
    private func requestAppleContactsAccess() {
        Task {
            _ = await appleContactsManager.requestAccess()
            if appleContactsManager.authorizationStatus == .authorized {
                loadAppleContacts()
            }
        }
    }
    
    private func loadAppleContacts() {
        guard appleContactsManager.authorizationStatus == .authorized else { return }
        
        isLoadingApple = true
        Task {
            do {
                appleContacts = try await appleContactsManager.fetchAllContacts()
            } catch {
                print("Failed to load Apple Contacts: \(error)")
            }
            isLoadingApple = false
        }
    }
    
    private func searchAppleContacts(_ query: String) {
        if query.isEmpty {
            // Already handled by filteredAppleContacts
            return
        }
    }
    
    private func selectAppleContact(_ contact: CNContact) {
        // Create a CRMContact from the Apple Contact and save to Supabase
        Task {
            let crmContact = CRMContact(
                appleContactId: contact.identifier,
                name: contact.fullName,
                email: contact.primaryEmail,
                phone: contact.primaryPhone,
                company: contact.organizationName.isEmpty ? nil : contact.organizationName
            )
            
            do {
                let repository = ContactRepository()
                let saved = try await repository.createContact(crmContact)
                await MainActor.run {
                    onSelect(saved)
                    dismiss()
                }
            } catch {
                // If save fails, still use the contact locally
                await MainActor.run {
                    onSelect(crmContact)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let name: String
    let company: String?
    let isBusinessContact: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isBusinessContact ? "briefcase.fill" : "person.circle.fill")
                .foregroundColor(isBusinessContact ? .accentColor : .secondary)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .lineLimit(1)
                if let company = company, !company.isEmpty {
                    Text(company)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }
}

#Preview {
    RecorderView()
        .frame(width: 390, height: 700)
}
