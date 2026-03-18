import AppKit
import Carbon

class PasteManager {
    private let pasteDelay: TimeInterval = 0.15
    private let eventDelayAfterActivate: TimeInterval = 0.05

    func paste(content: String) {
        print("[Paste] paste(content:) triggered")
        // 1. Copy content to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        performPasteToFrontmostApp()
    }
    
    func paste(item: ClipboardItem) {
        print("[Paste] paste(item:) triggered, type=\(item.type.rawValue)")
        // 1. Copy content to pasteboard based on type
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        switch item.type {
        case .text:
            pasteboard.setString(item.content, forType: .string)
        case .image:
            if let image = item.image {
                pasteboard.writeObjects([image])
            }
        }

        performPasteToFrontmostApp()
    }

    private func resolveTargetApp() -> NSRunningApplication? {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let appDelegate = NSApp.delegate as? AppDelegate

        // 1. Try AppDelegate's remembered target
        if let app = appDelegate?.preferredPasteTargetApplication() {
            print("[Paste] resolveTarget: via preferredPasteTarget = \(app.bundleIdentifier ?? "unknown")")
            return app
        }

        // 2. For accessory apps, menuBarOwningApplication is the "real" frontmost app
        if let menuBarApp = NSWorkspace.shared.menuBarOwningApplication,
           menuBarApp.processIdentifier != selfPID,
           !menuBarApp.isTerminated {
            print("[Paste] resolveTarget: via menuBar = \(menuBarApp.bundleIdentifier ?? "unknown")")
            return menuBarApp
        }

        // 3. NSWorkspace frontmost (if it's not self)
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != selfPID {
            print("[Paste] resolveTarget: via frontmostApplication = \(frontmost.bundleIdentifier ?? "unknown")")
            return frontmost
        }

        print("[Paste] resolveTarget: all methods failed")
        return nil
    }

    private func performPasteToFrontmostApp() {
        // Resolve target BEFORE hiding the window (menuBarOwningApplication is most reliable now)
        let targetApp = resolveTargetApp()
        print("[Paste] targetApp=\(targetApp?.bundleIdentifier ?? "nil")")

        // Close floating panel windows so user focus returns to target app quickly.
        NSApp.windows.forEach { window in
            if window.level == .floating {
                window.orderOut(nil)
            }
        }
        NSApp.deactivate()

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
            // Activate the target app (or re-resolve if still nil)
            let finalTarget = targetApp ?? self.resolveTargetApp()
            if let app = finalTarget {
                print("[Paste] activating target: \(app.bundleIdentifier ?? "unknown")")
                app.activate(options: [.activateAllWindows])
            } else {
                print("[Paste] no target app found, sending Cmd+V to current HID focus as fallback")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + self.eventDelayAfterActivate) {
                self.simulatePaste()
            }
        }
    }
    
    private func simulatePaste() {
        let isTrusted = AXIsProcessTrusted()
        print("[Paste] simulatePaste() running, AXIsProcessTrusted=\(isTrusted)")
        
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09 // kVK_ANSI_V
        let cmdKeyCode: CGKeyCode = 0x37 // kVK_Command
        
        print("[Paste] sending Cmd+V events")
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        vDown?.flags = .maskCommand
        
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        vUp?.flags = .maskCommand
        
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKeyCode, keyDown: false)
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
