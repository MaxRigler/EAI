// FloatingPanelController.swift
// Custom window controller for floating panel behavior

import SwiftUI
import AppKit

class FloatingPanelController: NSWindowController {
    
    // MARK: - Properties
    
    private var isExpanded = false
    private var hostingController: NSHostingController<AnyView>?
    
    // Window sizes
    private let compactSize = NSSize(width: 100, height: 120)
    private let expandedSize = NSSize(width: 390, height: 844)
    
    // MARK: - Initialization
    
    convenience init() {
        // Create a simple NSWindow first to ensure it works
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 100, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        
        setupWindow(window)
        setupContent()
        positionWindow()
        
        print("FloatingPanelController initialized, window: \(String(describing: self.window))")
    }
    
    // MARK: - Setup
    
    private func setupWindow(_ window: NSWindow) {
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isOpaque = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        // Important: make sure window can become visible
        window.isReleasedWhenClosed = false
    }
    
    private func setupContent() {
        updateContent()
    }
    
    private func updateContent() {
        let view: AnyView
        
        if isExpanded {
            view = AnyView(
                MainTabView(onCollapse: { [weak self] in
                    self?.toggleExpanded()
                })
                .frame(width: expandedSize.width, height: expandedSize.height)
                .background(VisualEffectBlur())
                .clipShape(RoundedRectangle(cornerRadius: 20))
            )
        } else {
            view = AnyView(
                HeadshotBar(onExpand: { [weak self] in
                    self?.toggleExpanded()
                })
                .frame(width: compactSize.width, height: compactSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            )
        }
        
        hostingController = NSHostingController(rootView: view)
        window?.contentViewController = hostingController
        
        print("Content updated, isExpanded: \(isExpanded)")
    }
    
    private func positionWindow() {
        guard let screen = NSScreen.main else {
            print("No main screen found!")
            return
        }
        
        let screenFrame = screen.visibleFrame
        let windowSize = isExpanded ? expandedSize : compactSize
        
        // Position in top-right corner
        let x = screenFrame.maxX - windowSize.width - 20
        let y = screenFrame.maxY - windowSize.height - 20
        
        window?.setFrame(NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height), display: true)
        
        print("Window positioned at: \(x), \(y)")
    }
    
    // MARK: - Override showWindow
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        
        // Force window to be visible
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        
        print("showWindow called, window is visible: \(window?.isVisible ?? false)")
    }
    
    // MARK: - Public Methods
    
    func toggleExpanded() {
        isExpanded.toggle()
        
        let newSize = isExpanded ? expandedSize : compactSize
        
        // Animate size change
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            guard let window = self.window else { return }
            var frame = window.frame
            
            // Keep top-right corner anchored
            let deltaHeight = newSize.height - frame.height
            
            frame.origin.y -= deltaHeight
            frame.size = newSize
            
            window.animator().setFrame(frame, display: true)
        } completionHandler: {
            self.updateContent()
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
