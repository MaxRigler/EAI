// StopRecordingModal.swift
// Confirmation screen displayed after stopping a recording (Confirm & Save)

import SwiftUI

// MARK: - ConfirmAndSaveView (main view)

struct ConfirmAndSaveView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var typesViewModel = RecordingTypesViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Recording Summary
                    recordingSummary
                    
                    Divider()
                    
                    // Recording Type Section
                    recordingTypeSection
                    
                    // Context Section
                    contextSection
                    
                    Divider()
                    
                    // Speaker Assignment Section
                    speakerSection
                    
                    // Validation errors
                    if !viewModel.validationErrors.isEmpty {
                        validationErrorsView
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Action buttons
            actionButtons
        }
        .frame(width: 380, height: 550)
        .onAppear {
            typesViewModel.loadRecordingTypes()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Confirm & Save")
                    .font(.headline)
                Text("Review your recording details before saving")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                viewModel.cancelStopRecording()
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Recording Summary
    
    private var recordingSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Recording Summary")
                    .font(.subheadline.weight(.semibold))
            }
            
            VStack(spacing: 8) {
                summaryRow(icon: "clock", label: "Duration", value: viewModel.formattedDuration)
                summaryRow(
                    icon: "mic.fill",
                    label: "Audio Input",
                    value: viewModel.selectedInput?.localizedName ?? "Default"
                )
                summaryRow(
                    icon: "speaker.wave.2.fill",
                    label: "System Audio",
                    value: viewModel.isSystemAudioEnabled ? "Enabled" : "Disabled",
                    valueColor: viewModel.isSystemAudioEnabled ? .green : .orange
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    private func summaryRow(icon: String, label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
    
    // MARK: - Recording Type Section
    
    private var recordingTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recording Type")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if viewModel.selectedRecordingType != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                }
            }
            
            if typesViewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if typesViewModel.recordingTypes.isEmpty {
                Text("No recording types available. Add types in Settings.")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(typesViewModel.recordingTypes) { type in
                        Button(action: {
                            viewModel.selectedRecordingType = type
                        }) {
                            HStack {
                                Text(type.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                if viewModel.selectedRecordingType?.id == type.id {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedRecordingType?.id == type.id
                                    ? Color.accentColor.opacity(0.2)
                                    : Color(NSColor.controlBackgroundColor)
                            )
                            .foregroundColor(
                                viewModel.selectedRecordingType?.id == type.id
                                    ? .accentColor
                                    : .primary
                            )
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        viewModel.selectedRecordingType?.id == type.id
                                            ? Color.accentColor
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Speaker Section
    
    private var speakerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Speakers")
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                // Add speaker button
                if viewModel.canAddSpeaker {
                    Button(action: { viewModel.addSpeaker() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Speaker")
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                // Status indicator
                let unassignedCount = viewModel.activeSpeakers.filter { $0 > 1 && viewModel.speakerAssignments[$0] == nil }.count
                if unassignedCount == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("\(unassignedCount) unassigned")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            VStack(spacing: 6) {
                ForEach(viewModel.activeSpeakers, id: \.self) { speakerNum in
                    ConfirmSpeakerRow(
                        speakerNumber: speakerNum,
                        assignedContact: viewModel.speakerAssignments[speakerNum],
                        isUser: speakerNum == 1,
                        canRemove: speakerNum > 1,
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
    }
    
    // MARK: - Context Section
    
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Context")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("Optional")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextEditor(text: $viewModel.recordingContext)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            
            Text("Additional notes for AI summarization (e.g., key topics, objectives)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Validation Errors
    
    private var validationErrorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Please complete the following:", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.orange)
            
            ForEach(viewModel.validationErrors, id: \.rawValue) { error in
                Text("• \(error.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                viewModel.discardRecording()
                dismiss()
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Discard")
                }
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
            
            Spacer()
            
            Button(action: {
                // Re-validate and complete if valid
                let errors = viewModel.validateRecording()
                if errors.isEmpty {
                    viewModel.completeRecording()
                    dismiss()
                } else {
                    viewModel.validationErrors = errors
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirm & Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedRecordingType == nil)
        }
        .padding()
    }
}

// MARK: - Confirm Speaker Row

struct ConfirmSpeakerRow: View {
    let speakerNumber: Int
    let assignedContact: CRMContact?
    let isUser: Bool
    var canRemove: Bool = false
    let onAssign: (CRMContact?) -> Void
    var onRemove: (() -> Void)? = nil
    
    @State private var showContactPicker = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Remove button for non-user speakers
            if canRemove {
                Button(action: { onRemove?() }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            
            // Speaker number badge
            Text("\(speakerNumber)")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(
                    isUser ? Color.accentColor :
                    (assignedContact != nil ? Color.green : Color.orange)
                )
                .clipShape(Circle())
            
            // Contact info or assign button
            if isUser {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.accentColor)
                    Text("Me (You)")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            } else {
                Button(action: { showContactPicker = true }) {
                    HStack {
                        if let contact = assignedContact {
                            Image(systemName: "person.fill")
                                .foregroundColor(.green)
                            Text(contact.name)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.orange)
                            Text("Assign Contact")
                                .foregroundColor(.orange)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        assignedContact == nil
                            ? Color.orange.opacity(0.1)
                            : Color(NSColor.controlBackgroundColor)
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerSheet(onSelect: onAssign)
        }
    }
}

// MARK: - Legacy alias (for backwards compatibility)

typealias StopRecordingModal = ConfirmAndSaveView

#Preview {
    ConfirmAndSaveView(viewModel: RecorderViewModel.shared)
}
