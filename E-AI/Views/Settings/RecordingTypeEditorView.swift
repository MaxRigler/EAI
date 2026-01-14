// RecordingTypeEditorView.swift
// Modal for adding and editing recording types

import SwiftUI

struct RecordingTypeEditorView: View {
    @Environment(\.dismiss) var dismiss
    
    let existingType: RecordingType?
    let onSave: (RecordingType) -> Void
    
    @State private var name: String = ""
    @State private var promptTemplate: String = ""
    @State private var isActive: Bool = true
    
    var isEditing: Bool { existingType != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    init(existingType: RecordingType? = nil, onSave: @escaping (RecordingType) -> Void) {
        self.existingType = existingType
        self.onSave = onSave
        
        if let existing = existingType {
            _name = State(initialValue: existing.name)
            _promptTemplate = State(initialValue: existing.promptTemplate)
            _isActive = State(initialValue: existing.isActive)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Recording Type" : "New Recording Type")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.headline)
                        
                        TextField("e.g., Client Support, Cold Call", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Prompt template field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt Template")
                            .font(.headline)
                        
                        Text("This prompt will be used when AI summarizes recordings of this type.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $promptTemplate)
                            .font(.body)
                            .frame(minHeight: 200)
                            .padding(8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }
                    
                    // Active toggle (only show when editing)
                    if isEditing {
                        Divider()
                        
                        Toggle("Active", isOn: $isActive)
                            .toggleStyle(.switch)
                        
                        Text(isActive ? "This recording type will appear in the recorder." : "This recording type is hidden from the recorder.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("Save") {
                    saveRecordingType()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 450)
    }
    
    private func saveRecordingType() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let type: RecordingType
        if let existing = existingType {
            type = RecordingType(
                id: existing.id,
                name: trimmedName,
                promptTemplate: promptTemplate,
                isActive: isActive,
                createdAt: existing.createdAt
            )
        } else {
            type = RecordingType(
                name: trimmedName,
                promptTemplate: promptTemplate
            )
        }
        
        onSave(type)
        dismiss()
    }
}

#Preview("New") {
    RecordingTypeEditorView { type in
        print("Saved: \(type.name)")
    }
}

#Preview("Edit") {
    RecordingTypeEditorView(
        existingType: RecordingType(
            name: "Cold Call",
            promptTemplate: "Analyze this cold call..."
        )
    ) { type in
        print("Updated: \(type.name)")
    }
}
