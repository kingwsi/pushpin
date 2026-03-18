import SwiftUI
import AppKit

class ToastManager {
    static let shared = ToastManager()
    private var toastWindow: NSWindow?
    private var dismissWorkItem: DispatchWorkItem?

    func showToast(message: String) {
        DispatchQueue.main.async {
            self.internalShowToast(message: message)
        }
    }

    private func internalShowToast(message: String) {
        if toastWindow == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 60),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered,
                                defer: false)
            panel.level = .floating + 1
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            toastWindow = panel
        }
        
        let toastView = NSHostingView(rootView: ToastView(title: message))
        toastWindow?.contentView = toastView
        
        // Exact measure after setting content
        let fittingSize = toastView.fittingSize
        toastWindow?.setContentSize(fittingSize)
        
        // Position near the mouse cursor
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame
        
        // Position slightly below and to the right of the cursor
        var x = mouseLoc.x + 16
        var y = mouseLoc.y - fittingSize.height - 16
        
        // Prevent going off right edge
        if x + fittingSize.width > screenFrame.maxX {
            x = mouseLoc.x - fittingSize.width - 16
        }
        // Prevent going off bottom edge
        if y < screenFrame.minY {
            y = mouseLoc.y + 16
        }
        
        toastWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        
        // Cancel previous dismissal if triggered again
        dismissWorkItem?.cancel()
        
        // Fade in
        toastWindow?.alphaValue = 0.0
        toastWindow?.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            toastWindow?.animator().alphaValue = 1.0
        }
        
        // Schedule fade out
        let workItem = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                self?.toastWindow?.animator().alphaValue = 0.0
            }, completionHandler: {
                self?.toastWindow?.orderOut(nil)
            })
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
}

struct ToastView: View {
    let title: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 15))
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(20) // Padding around capsule to give shadow room to render
    }
}
