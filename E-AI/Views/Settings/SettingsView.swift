// SettingsView.swift
// Configuration and system management

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Settings content
            ScrollView {
                VStack(spacing: 24) {
                    // Needs Attention section (if any issues)
                    if viewModel.hasIssues {
                        needsAttentionSection
                    }
                    
                    // Recording Types
                    recordingTypesSection
                    
                    // Audio Configuration
                    audioConfigSection
                    
                    // File Storage
                    fileStorageSection
                    
                    // API Configuration
                    apiConfigSection
                    
                    // About
                    aboutSection
                }
                .padding()
            }
        }
        .frame(minWidth: 350, minHeight: 500)
        .onAppear {
            viewModel.loadSettings()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showRecordingTypeEditor },
            set: { if !$0 { viewModel.dismissRecordingTypeEditor() } }
        )) {
            RecordingTypeEditorView(
                existingType: viewModel.editingRecordingType
            ) { type in
                viewModel.saveRecordingType(type)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("Done") { dismiss() }
        }
        .padding()
    }
    
    // MARK: - Needs Attention Section
    
    private var needsAttentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Needs Attention")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.issueCount)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            ForEach(viewModel.issues) { issue in
                IssueRow(issue: issue, onRetry: {
                    viewModel.retryIssue(issue)
                }, onDismiss: {
                    viewModel.dismissIssue(issue)
                })
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Recording Types Section
    
    private var recordingTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.accentColor)
                Text("Recording Types")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { viewModel.showAddRecordingType = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            
            ForEach(viewModel.recordingTypes) { type in
                RecordingTypeRow(type: type, onEdit: {
                    viewModel.editRecordingType(type)
                }, onDelete: {
                    viewModel.deleteRecordingType(type)
                })
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Audio Config Section
    
    private var audioConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
                Text("Audio Configuration")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Microphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(viewModel.availableInputs, id: \.uniqueID) { device in
                        Button(device.localizedName) {
                            viewModel.setDefaultInput(device)
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.defaultInput?.localizedName ?? "System Default")
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // System audio note
            VStack(alignment: .leading, spacing: 4) {
                Text("System Audio Capture")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Coming soon. Requires additional audio routing setup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - File Storage Section
    
    private var fileStorageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                Text("File Storage")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Recording Storage Path")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(viewModel.storagePath)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button("Change") {
                        viewModel.selectStoragePath()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - API Config Section
    
    private var apiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                Text("API Configuration")
                    .font(.headline)
            }
            
            VStack(spacing: 8) {
                APIKeyRow(name: "Supabase", isConfigured: viewModel.hasSupabaseKey)
                APIKeyRow(name: "Claude (Anthropic)", isConfigured: viewModel.hasClaudeKey)
                APIKeyRow(name: "OpenAI", isConfigured: viewModel.hasOpenAIKey)
            }
            
            Button(action: { viewModel.showAPIKeySetup = true }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Reconfigure API Keys")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("About")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("E-AI")
                    .font(.body)
                    .fontWeight(.semibold)
                
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("AI-Powered CRM for Equity Advance")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Issue Row

struct IssueRow: View {
    let issue: SettingsIssue
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.subheadline)
                
                Text(issue.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Recording Type Row

struct RecordingTypeRow: View {
    let type: RecordingType
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(type.name)
                .font(.body)
            
            Spacer()
            
            if !type.isActive {
                Text("Inactive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - API Key Row

struct APIKeyRow: View {
    let name: String
    let isConfigured: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(.body)
            
            Spacer()
            
            if isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Configured")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Not configured")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Settings Issue Model

struct SettingsIssue: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: IssueType
    
    enum IssueType {
        case transcriptionFailed
        case summarizationFailed
        case syncFailed
    }
}

#Preview {
    SettingsView()
        .frame(width: 400, height: 700)
}
