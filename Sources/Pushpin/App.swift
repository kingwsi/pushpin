import SwiftUI
import AppKit

@main
struct PushpinApp: App {
    @State private var clipboardManager = ClipboardManager()
    @State private var hotkeyManager = HotkeyManager()
    @State private var pasteManager = PasteManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // prevent App Nap
        ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Hotkey Monitoring")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(clipboardManager)
                .environment(hotkeyManager)
                .environment(\.pasteManager, pasteManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy first
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pushpin")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        // Store window reference and prevent it from being released
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                self.mainWindow = window
                // Prevent window from releasing when closed
                window.isReleasedWhenClosed = false
                // Allow window to accept mouse events even when not key
                window.acceptsMouseMovedEvents = true
                // Make clicks activate and pass through in one click
                window.collectionBehavior.insert(.canJoinAllSpaces)
                window.level = .floating
                print("Main window stored and configured: \(self.mainWindow != nil)")
            } else {
                print("Warning: Could not find main window")
            }
        }
    }
    
    @objc func toggleWindow() {
        print("Toggle window called")
        
        // Try to get the window if we don't have it
        if mainWindow == nil {
            mainWindow = NSApp.windows.first(where: { $0.canBecomeKey })
            if let window = mainWindow {
                window.isReleasedWhenClosed = false
                window.acceptsMouseMovedEvents = true
                window.collectionBehavior.insert(.canJoinAllSpaces)
                window.level = .floating
                print("Window found and stored")
            }
        }
        
        guard let window = mainWindow else {
            print("No window found")
            return
        }
        
        print("Window isVisible: \(window.isVisible)")
        
        if window.isVisible {
            print("Hiding window")
            window.orderOut(nil)
        } else {
            print("Showing window")
            
            // Get mouse location
            let mouseLocation = NSEvent.mouseLocation
            print("Mouse location: \(mouseLocation)")
            
            // Get the screen containing the mouse
            let screen = NSScreen.screens.first { screen in
                NSMouseInRect(mouseLocation, screen.frame, false)
            } ?? NSScreen.main ?? NSScreen.screens[0]
            
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            
            // Calculate initial position (near mouse, with offset)
            var windowX = mouseLocation.x + 10
            var windowY = mouseLocation.y - 10
            
            // Adjust X position to keep window on screen
            if windowX + windowSize.width > screenFrame.maxX {
                // Too far right, position to the left of mouse
                windowX = mouseLocation.x - windowSize.width - 10
            }
            if windowX < screenFrame.minX {
                // Too far left, align to left edge
                windowX = screenFrame.minX + 10
            }
            
            // Adjust Y position to keep window on screen
            if windowY - windowSize.height < screenFrame.minY {
                // Too low, position above mouse
                windowY = mouseLocation.y + 10
            }
            if windowY > screenFrame.maxY {
                // Too high, align to top edge
                windowY = screenFrame.maxY - 10
            }
            
            // Set window position
            let newOrigin = NSPoint(x: windowX, y: windowY - windowSize.height)
            window.setFrameOrigin(newOrigin)
            
            print("Window positioned at: \(newOrigin)")
            
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        print("applicationShouldTerminateAfterLastWindowClosed called")
        return false
    }
}

// Environment key for PasteManager
private struct PasteManagerKey: EnvironmentKey {
    static let defaultValue = PasteManager()
}

extension EnvironmentValues {
    var pasteManager: PasteManager {
        get { self[PasteManagerKey.self] }
        set { self[PasteManagerKey.self] = newValue }
    }
}

// Extension to help with window management
extension PushpinApp {
    // We can't easily add onReceive to WindowGroup in the same way as a View, 
    // but we can add it to the ContentView or use an adapter.
    // Actually, let's add it to ContentView for simplicity, or wrap ContentView.
}
