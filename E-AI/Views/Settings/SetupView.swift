// SetupView.swift
// First-launch setup wizard for API keys

import SwiftUI

struct SetupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = SetupViewModel()
    @State private var currentStep = 0
    
    /// Callback when setup is complete (used when presented as standalone window)
    var onComplete: (() -> Void)?
    
    init(onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            // Progress indicator
            progressIndicator
            
            // Step content
            stepContent
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("Welcome to E-AI")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Let's set up your AI-powered CRM")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Step Content
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            supabaseStep
        case 1:
            claudeStep
        case 2:
            openaiStep
        case 3:
            completeStep
        default:
            EmptyView()
        }
    }
    
    // MARK: - Supabase Step
    
    private var supabaseStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supabase Configuration")
                .font(.headline)
            
            Text("Enter your Supabase project credentials. These will be stored securely in your Mac's Keychain.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Project URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("https://xxxxx.supabase.co", text: $viewModel.supabaseUrl)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key (anon/public)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("sb_...", text: $viewModel.supabaseKey)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    // MARK: - Claude Step
    
    private var claudeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Claude API Configuration")
                .font(.headline)
            
            Text("Enter your Anthropic API key for call summarization and chat functionality.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("sk-ant-...", text: $viewModel.claudeApiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            Link("Get an API key from Anthropic", destination: URL(string: "https://console.anthropic.com")!)
                .font(.caption)
        }
    }
    
    // MARK: - OpenAI Step
    
    private var openaiStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("OpenAI API Configuration")
                .font(.headline)
            
            Text("Enter your OpenAI API key for generating embeddings (semantic search).")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("sk-proj-...", text: $viewModel.openaiApiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            Link("Get an API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.caption)
        }
    }
    
    // MARK: - Complete Step
    
    private var completeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("All Set!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your E-AI is ready to use. Start recording calls and building your second brain.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if viewModel.isValidating {
                ProgressView("Validating configuration...")
            } else if let error = viewModel.validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 && currentStep < 3 {
                Button("Back") {
                    currentStep -= 1
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            if currentStep < 3 {
                Button("Next") {
                    currentStep += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            } else {
                Button("Get Started") {
                    Task {
                        await viewModel.saveConfiguration()
                        if viewModel.validationError == nil {
                            if let onComplete = onComplete {
                                onComplete()
                            } else {
                                dismiss()
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isValidating)
            }
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return !viewModel.supabaseUrl.isEmpty && !viewModel.supabaseKey.isEmpty
        case 1:
            return !viewModel.claudeApiKey.isEmpty
        case 2:
            return !viewModel.openaiApiKey.isEmpty
        default:
            return true
        }
    }
}

// MARK: - Setup ViewModel

@MainActor
class SetupViewModel: ObservableObject {
    @Published var supabaseUrl = ""
    @Published var supabaseKey = ""
    @Published var claudeApiKey = ""
    @Published var openaiApiKey = ""
    
    @Published var isValidating = false
    @Published var validationError: String?
    
    func saveConfiguration() async {
        isValidating = true
        validationError = nil
        
        do {
            let keychain = KeychainManager.shared
            
            try keychain.setSupabaseURL(supabaseUrl)
            try keychain.setSupabaseKey(supabaseKey)
            try keychain.setClaudeAPIKey(claudeApiKey)
            try keychain.setOpenAIAPIKey(openaiApiKey)
            
            // Initialize Supabase with new credentials
            await SupabaseManager.shared.initialize()
            
            isValidating = false
        } catch {
            validationError = error.localizedDescription
            isValidating = false
        }
    }
}

#Preview {
    SetupView()
}
