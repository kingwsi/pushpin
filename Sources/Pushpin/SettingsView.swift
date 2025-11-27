import SwiftUI
import Carbon

struct SettingsView: View {
    @Environment(HotkeyManager.self) private var hotkeyManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            Form {
                Section("Global Hotkey") {
                    KeyRecorder(hotkeyManager: hotkeyManager)
                }
            }
            .formStyle(.grouped)
            
            Button("Done") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 350, height: 250)
    }
}

struct KeyRecorder: View {
    var hotkeyManager: HotkeyManager
    @State private var isRecording = false
    @State private var monitor: Any?
    
    var body: some View {
        HStack {
            Text("Shortcut:")
            Spacer()
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                Text(displayText)
                    .frame(minWidth: 100)
            }
        }
    }
    
    private var displayText: String {
        if isRecording {
            return "Press keys..."
        }
        return keyString(for: hotkeyManager.currentHotkey)
    }
    
    private func startRecording() {
        isRecording = true
        // Add local monitor
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore just modifier keys
            if event.keyCode == 55 || event.keyCode == 56 || event.keyCode == 58 || event.keyCode == 59 || event.keyCode == 60 || event.keyCode == 61 || event.keyCode == 62 || event.keyCode == 63 {
                return event
            }
            
            // Convert NSEvent modifiers to Carbon modifiers
            var carbonModifiers: UInt32 = 0
            if event.modifierFlags.contains(.command) { carbonModifiers |= UInt32(kCarbonCmdKey) }
            if event.modifierFlags.contains(.option) { carbonModifiers |= UInt32(kCarbonOptionKey) }
            if event.modifierFlags.contains(.control) { carbonModifiers |= UInt32(kCarbonControlKey) }
            if event.modifierFlags.contains(.shift) { carbonModifiers |= UInt32(kCarbonShiftKey) }
            
            print("Recorded key: \(event.keyCode), mods: \(carbonModifiers)")
            
            // Update hotkey
            hotkeyManager.updateHotkey(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
            
            stopRecording()
            return nil // Consume event
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    private func keyString(for hotkey: Hotkey) -> String {
        var string = ""
        if (hotkey.modifiers & UInt32(kCarbonCmdKey)) != 0 { string += "⌘" }
        if (hotkey.modifiers & UInt32(kCarbonShiftKey)) != 0 { string += "⇧" }
        if (hotkey.modifiers & UInt32(kCarbonOptionKey)) != 0 { string += "⌥" }
        if (hotkey.modifiers & UInt32(kCarbonControlKey)) != 0 { string += "⌃" }
        
        // Simple mapping for common keys, can be expanded
        // This is a very basic mapping. In a real app, we'd use TIS functions to map keycode to string.
        switch hotkey.keyCode {
        case 0: string += "A"
        case 1: string += "S"
        case 2: string += "D"
        case 3: string += "F"
        case 4: string += "H"
        case 5: string += "G"
        case 6: string += "Z"
        case 7: string += "X"
        case 8: string += "C"
        case 9: string += "V"
        case 11: string += "B"
        case 12: string += "Q"
        case 13: string += "W"
        case 14: string += "E"
        case 15: string += "R"
        case 16: string += "Y"
        case 17: string += "T"
        case 31: string += "O"
        case 34: string += "I"
        case 35: string += "P"
        case 37: string += "L"
        case 38: string += "J"
        case 40: string += "K"
        case 45: string += "N"
        case 46: string += "M"
        default: string += "Key \(hotkey.keyCode)"
        }
        
        return string
    }
}
