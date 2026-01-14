// DraggableBar.swift
// Compact mode view - a thin draggable bar with live recording status

import SwiftUI

struct DraggableBar: View {
    let onExpand: () -> Void
    
    // Bind to shared RecorderViewModel for live recording state
    @ObservedObject private var viewModel = RecorderViewModel.shared
    
    var body: some View {
        HStack(spacing: 10) {
            // Recording status indicator
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.green)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(viewModel.isRecording ? Color.red.opacity(0.4) : Color.clear, lineWidth: 2)
                        .scaleEffect(viewModel.isRecording ? 1.5 : 1.0)
                        .opacity(viewModel.isRecording ? 0.6 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)
                )
            
            // Status text - show timer when recording
            if viewModel.isRecording {
                Text(viewModel.formattedDuration)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.red)
            } else {
                Text("E-AI")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Compact record/stop button
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
                        .frame(width: 24, height: 24)
                    
                    if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)
            .help(viewModel.isRecording ? "Stop Recording" : "Start Recording")
            
            // Expand button
            Button(action: onExpand) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Expand")
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    DraggableBar(onExpand: {})
        .frame(width: 220, height: 44)
        .background(Color(NSColor.windowBackgroundColor))
}
