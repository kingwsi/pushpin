import SwiftUI
import AppKit

enum ThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@main
struct PushpinApp: App {
    @State private var clipboardManager = ClipboardManager()
    @State private var hotkeyManager = HotkeyManager()
    @State private var pasteManager = PasteManager()
    @AppStorage("ThemeMode") private var themeMode = ThemeMode.system.rawValue
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // prevent App Nap
        ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Hotkey Monitoring")
    }
    
    var body: some Scene {
        WindowGroup {
            ThemeProvider {
                ContentView()
                    .environment(clipboardManager)
                    .environment(hotkeyManager)
                    .environment(\.pasteManager, pasteManager)
                    .frame(minWidth: 320, minHeight: 400)
                    .onAppear {
                        applyAppAppearance()
                    }
                    .onChange(of: themeMode) { _, _ in
                        applyAppAppearance()
                    }
            }
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        WindowGroup("JSON Editor", for: UUID.self) { $itemId in
            if let id = itemId,
               let index = clipboardManager.history.firstIndex(where: { $0.id == id }) {
                ThemeProvider {
                    JsonEditorView(text: Binding(
                        get: { clipboardManager.history[index].content },
                        set: { clipboardManager.history[index].content = $0 }
                    ))
                    .navigationTitle("JSON Editor")
                    .onAppear {
                        applyAppAppearance()
                    }
                }
            } else {
                ContentUnavailableView("Item Not Found", systemImage: "questionmark.folder")
            }
        }
        .environment(clipboardManager)
        .defaultSize(width: 600, height: 500)
    }

    private func applyAppAppearance() {
        let appearance: NSAppearance?
        switch ThemeMode(rawValue: themeMode) ?? .system {
        case .system:
            appearance = nil
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }
        
        NSApp.appearance = appearance
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var mainWindow: NSWindow?
    private(set) var lastExternalActiveApp: NSRunningApplication?
    private var workspaceObserver: NSObjectProtocol?
    private let accessibilityPromptedKey = "HasPromptedAccessibility"
    private let accessibilityReminderDateKey = "LastAccessibilityReminderDate"
    private let accessibilityReminderInterval: TimeInterval = 60 * 60 * 24
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.applicationIconImage = NSImage(named: "AppIcon")
        // Set activation policy first
        NSApp.setActivationPolicy(.accessory)
        
        // Check accessibility permission on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAccessibilityPermission()
        }
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(paletteColors: [.white])
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pushpin")?.withSymbolConfiguration(config)
            image?.isTemplate = false
            button.image = image
            button.action = #selector(toggleWindow)
            button.target = self
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let runningApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            if runningApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self.lastExternalActiveApp = runningApp
                print("[App] observer captured: \(runningApp.bundleIdentifier ?? "pid=\(runningApp.processIdentifier)")")
            }
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
                
                // Configure vibrancy effect
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                
                print("Main window stored and configured: \(self.mainWindow != nil)")
            } else {
                print("Warning: Could not find main window")
            }
        }
    }
    
    private func checkAccessibilityPermission() {
        // Only check if not already prompted
        let hasPrompted = UserDefaults.standard.bool(forKey: accessibilityPromptedKey)
        
        if !AccessibilityManager.checkAccessibility() {
            if !hasPrompted {
                // First time, request with system prompt
                AccessibilityManager.requestAccessibility()
                UserDefaults.standard.set(true, forKey: accessibilityPromptedKey)
                return
            }

            guard shouldShowAccessibilityReminder() else {
                return
            }

            // Subsequent times, show our custom alert only when a window is available.
            guard let window = mainWindow ?? NSApp.windows.first(where: { $0.canBecomeKey }) else {
                return
            }

            AccessibilityManager.showAccessibilityAlert(attachedTo: window) {
                AccessibilityManager.openAccessibilitySettings()
            }
            UserDefaults.standard.set(Date(), forKey: accessibilityReminderDateKey)
        }
    }

    private func shouldShowAccessibilityReminder() -> Bool {
        guard let lastReminderDate = UserDefaults.standard.object(forKey: accessibilityReminderDateKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastReminderDate) >= accessibilityReminderInterval
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
                
                // Configure vibrancy effect
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                
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
            captureLastExternalActiveApp()
            
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

    func preferredPasteTargetApplication() -> NSRunningApplication? {
        if let app = lastExternalActiveApp, !app.isTerminated {
            return app
        }
        // For accessory apps, menuBarOwningApplication is the "real" frontmost app
        let selfPID = ProcessInfo.processInfo.processIdentifier
        if let menuBarApp = NSWorkspace.shared.menuBarOwningApplication,
           menuBarApp.processIdentifier != selfPID,
           !menuBarApp.isTerminated {
            print("[App] preferredTarget via menuBar: \(menuBarApp.bundleIdentifier ?? "unknown")")
            lastExternalActiveApp = menuBarApp
            return menuBarApp
        }
        if let fallback = detectFrontmostAppByWindowList() {
            print("[App] preferredTarget via CGWindowList: \(fallback.bundleIdentifier ?? "unknown")")
            lastExternalActiveApp = fallback
            return fallback
        }
        print("[App] preferredTarget: all methods failed")
        return nil
    }

    func captureLastExternalActiveApp() {
        let selfPID = ProcessInfo.processInfo.processIdentifier

        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != selfPID {
            lastExternalActiveApp = frontmost
            print("[App] captured target via NSWorkspace: \(frontmost.bundleIdentifier ?? "unknown")")
            return
        }

        // For accessory apps, menuBarOwningApplication is more reliable
        if let menuBarApp = NSWorkspace.shared.menuBarOwningApplication,
           menuBarApp.processIdentifier != selfPID,
           !menuBarApp.isTerminated {
            lastExternalActiveApp = menuBarApp
            print("[App] captured target via menuBar: \(menuBarApp.bundleIdentifier ?? "unknown")")
            return
        }

        if let fallback = detectFrontmostAppByWindowList() {
            lastExternalActiveApp = fallback
            print("[App] captured target via CGWindowList: \(fallback.bundleIdentifier ?? "unknown")")
            return
        }

        print("[App] captureLastExternalActiveApp: all methods failed")
    }

    private func detectFrontmostAppByWindowList() -> NSRunningApplication? {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard
            let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else {
            return nil
        }

        for info in windowInfo {
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t else { continue }
            if ownerPID == selfPID { continue }
            if let app = NSRunningApplication(processIdentifier: ownerPID), !app.isTerminated {
                return app
            }
        }
        return nil
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
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

struct ThemeProvider<Content: View>: View {
    @AppStorage("ThemeMode") private var themeMode = ThemeMode.system.rawValue
    @Environment(\.colorScheme) private var systemColorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.colorScheme, activeScheme)
    }

    private var activeScheme: ColorScheme {
        switch ThemeMode(rawValue: themeMode) ?? .system {
        case .system: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }
}
