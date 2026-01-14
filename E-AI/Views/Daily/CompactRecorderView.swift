// CompactRecorderView.swift
// Compact recording controls for the Daily view header

import SwiftUI
import AVFoundation

struct CompactRecorderView: View {
    @ObservedObject private var viewModel = RecorderViewModel.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Main recording row
            HStack(spacing: 16) {
                // Record/Stop button
                recordButton
                
                // Timer and status
                VStack(alignment: .leading, spacing: 2) {
                    if viewModel.isRecording {
                        Text(viewModel.formattedDuration)
                            .font(.system(size: 24, weight: .light, design: .monospaced))
                            .foregroundColor(.red)
                        
                        Text("Recording...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Start Recording")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Tap to begin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Audio input selector
                audioInputSelector
            }
        }
        .padding()
        .background(
            viewModel.isRecording
                ? Color.red.opacity(0.05)
                : Color(NSColor.windowBackgroundColor).opacity(0.5)
        )
        .overlay(
            Rectangle()
                .frame(height: viewModel.isRecording ? 2 : 0)
                .foregroundColor(.red.opacity(0.5))
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: viewModel.isRecording),
            alignment: .bottom
        )
        .sheet(isPresented: $viewModel.showStopRecordingModal) {
            ConfirmAndSaveView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadRecordingTypes()
        }
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
                    .frame(width: 56, height: 56)
                    .shadow(color: (viewModel.isRecording ? Color.red : Color.accentColor).opacity(0.4), radius: 6, y: 3)
                
                if viewModel.isRecording {
                    // Stop icon (square)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                } else {
                    // Record icon (circle)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                }
            }
        }
        .buttonStyle(.plain)
        .help(viewModel.isRecording ? "Stop Recording" : "Start Recording")
    }
    
    // MARK: - Audio Input Selector
    
    private var audioInputSelector: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Microphone dropdown
            Menu {
                ForEach(viewModel.availableInputs, id: \.uniqueID) { device in
                    Button(device.localizedName) {
                        viewModel.selectInput(device)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(viewModel.selectedInput?.localizedName ?? "Select Input")
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: 100, alignment: .trailing)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            // System audio indicator
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 8))
                    .foregroundColor(viewModel.isSystemAudioEnabled ? .green : .orange)
                Text(viewModel.isSystemAudioEnabled ? "System: On" : "System: Off")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(viewModel.isSystemAudioEnabled ? .green : .orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                viewModel.isSystemAudioEnabled
                    ? Color.green.opacity(0.15)
                    : Color.orange.opacity(0.15)
            )
            .cornerRadius(4)
        }
    }
}

#Preview {
    VStack {
        CompactRecorderView()
        Spacer()
    }
    .frame(width: 390, height: 300)
}
