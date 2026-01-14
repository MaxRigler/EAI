// HeadshotBar.swift
// Compact mode view - headshot avatar with interactive eye and dropdown arrow

import SwiftUI

struct HeadshotBar: View {
    let onExpand: () -> Void
    
    // Bind to shared RecorderViewModel for live recording state
    @ObservedObject private var viewModel = RecorderViewModel.shared
    
    // Animation state for blinking eye
    @State private var eyeOpacity: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Headshot image - tappable to open app ONLY when recording
                Image("RaxMigler")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // When recording, clicking anywhere opens the app
                        if viewModel.isRecording {
                            onExpand()
                        }
                    }
                
                // Red eye overlay - ONLY starts recording (when not recording)
                // When recording, tapping anywhere opens the app instead
                if !viewModel.isRecording {
                    Button(action: {
                        viewModel.startRecording()
                    }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * 0.15, height: geometry.size.width * 0.15)
                            .opacity(0.8)
                            .shadow(color: .red.opacity(0.8), radius: 3)
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: geometry.size.width * 0.62,
                        y: geometry.size.height * 0.42
                    )
                    .help("Start Recording")
                }
                
                // Blinking red eye indicator when recording (not a button, just visual)
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: geometry.size.width * 0.15, height: geometry.size.width * 0.15)
                        .opacity(eyeOpacity)
                        .shadow(color: .red.opacity(0.8), radius: 10)
                        .position(
                            x: geometry.size.width * 0.62,
                            y: geometry.size.height * 0.42
                        )
                        .allowsHitTesting(false) // Let tap go through to headshot
                }
                
                // White dropdown arrow - only visible when NOT recording
                // (When recording, tapping anywhere opens app)
                if !viewModel.isRecording {
                    Button(action: onExpand) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: geometry.size.width * 0.18, height: geometry.size.width * 0.18)
                                .shadow(color: .black.opacity(0.3), radius: 2)
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: geometry.size.width * 0.08, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: geometry.size.width * 0.88,
                        y: geometry.size.height * 0.90
                    )
                    .help("Expand App")
                }
            }
        }
        .onAppear {
            startBlinkingIfNeeded()
        }
        .onChange(of: viewModel.isRecording) { isRecording in
            if isRecording {
                startBlinking()
            } else {
                stopBlinking()
            }
        }
    }
    
    private func startBlinkingIfNeeded() {
        if viewModel.isRecording {
            startBlinking()
        }
    }
    
    private func startBlinking() {
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            eyeOpacity = 0.3
        }
    }
    
    private func stopBlinking() {
        withAnimation(.easeInOut(duration: 0.2)) {
            eyeOpacity = 1.0
        }
    }
}

#Preview {
    HeadshotBar(onExpand: {})
        .frame(width: 100, height: 120)
        .background(Color.gray.opacity(0.3))
}
