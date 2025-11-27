import Carbon
import AppKit

// Carbon constants
let kCarbonCmdKey = 0x0100
let kCarbonShiftKey = 0x0200
let kCarbonOptionKey = 0x0800
let kCarbonControlKey = 0x1000

struct Hotkey: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
}

@Observable
class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    
    // Default: Cmd + Shift + V (keyCode 9)
    var currentHotkey: Hotkey {
        didSet {
            registerHotkey()
            saveHotkey()
        }
    }
    
    init() {
        // Load from UserDefaults or use default
        if let data = UserDefaults.standard.data(forKey: "GlobalHotkey"),
           let saved = try? JSONDecoder().decode(Hotkey.self, from: data) {
            self.currentHotkey = saved
        } else {
            self.currentHotkey = Hotkey(keyCode: 9, modifiers: UInt32(kCarbonCmdKey | kCarbonShiftKey))
        }
        
        installEventHandler()
        registerHotkey()
    }
    
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        print("Updating hotkey to: key \(keyCode), mods \(modifiers)")
        self.currentHotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    private func registerHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(1752460081) // 'hkey'
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(currentHotkey.keyCode,
                                         currentHotkey.modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
        } else {
            print("Successfully registered hotkey: \(currentHotkey)")
        }
    }
        
        // Install event handler only once (if not already installed)
        // Note: In a real app we might want to track if the handler is installed.
        // For simplicity, we assume init() installs it once.
        // But wait, init() calls registerHotkey(). We should move the handler installation to init.
    
    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            // Forward to the Swift class instance
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue()
            manager.handleHotkey()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
    
    private func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.toggleVisibility()
        }
    }
    
    private func toggleVisibility() {
        guard let window = NSApp.windows.first(where: { $0.canBecomeKey }) else {
            print("HotkeyManager: No window found")
            return
        }
        
        if window.isVisible {
            window.orderOut(nil)
        } else {
            // Get mouse location
            let mouseLocation = NSEvent.mouseLocation
            
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
            
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func saveHotkey() {
        if let encoded = try? JSONEncoder().encode(currentHotkey) {
            UserDefaults.standard.set(encoded, forKey: "GlobalHotkey")
        }
    }
    
    deinit {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
        }
    }
}
