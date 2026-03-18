import SwiftUI
import Carbon

struct SettingsView: View {
    @Environment(HotkeyManager.self) private var hotkeyManager
    @Environment(ClipboardManager.self) private var clipboardManager
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("MaxHistoryCount") private var maxHistoryCount = 50
    @AppStorage("ThemeMode") private var themeMode = ThemeMode.system.rawValue
    @State private var hasAccessibilityPermission = AccessibilityManager.checkAccessibility()
    let isEmbedded: Bool
    let onDone: (() -> Void)?

    init(isEmbedded: Bool = false, onDone: (() -> Void)? = nil) {
        self.isEmbedded = isEmbedded
        self.onDone = onDone
    }
    
    var body: some View {
        VStack(spacing: isEmbedded ? 12 : 14) {
            if !isEmbedded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.title3.weight(.semibold))
                    Text("Customize shortcuts, history, and permissions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    settingsCard(title: "Appearance", subtitle: "Theme") {
                        HStack(spacing: 12) {
                            fieldLabel("Theme")
                            Picker("Theme", selection: $themeMode) {
                                ForEach(ThemeMode.allCases) { mode in
                                    Text(mode.title).tag(mode.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }
                    }

                    settingsCard(title: "Keyboard", subtitle: "Global shortcut") {
                        HStack(spacing: 12) {
                            fieldLabel("Global Hotkey")
                            KeyRecorder(hotkeyManager: hotkeyManager)
                            Spacer(minLength: 0)
                        }
                    }

                    settingsCard(title: "History", subtitle: "Storage limits") {
                        HStack(spacing: 12) {
                            fieldLabel("Max History")
                            Stepper(value: $maxHistoryCount, in: 10...200, step: 10) {
                                Text("\(maxHistoryCount) items")
                                    .font(.body.monospacedDigit())
                                    .frame(minWidth: 90, alignment: .leading)
                            }
                            .onChange(of: maxHistoryCount) { _, _ in
                                // Trim history if new limit is lower than current count
                                clipboardManager.trimHistory()
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    settingsCard(title: "Permissions", subtitle: "Required for auto-paste") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                fieldLabel("辅助功能权限")
                                accessibilityStatusBadge
                                Spacer(minLength: 0)

                                if !hasAccessibilityPermission {
                                    Button("授权") {
                                        AccessibilityManager.openAccessibilitySettings()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }

                            Text("需要此权限才能自动粘贴内容")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 126)
                        }
                    }

                    settingsCard(title: "Project", subtitle: "Open source") {
                        HStack(spacing: 12) {
                            fieldLabel("Source Code")
                            Button(action: {
                                if let url = URL(string: "https://github.com/kingwsi/pushpin") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Label("GitHub Repository", systemImage: "arrow.up.forward.square")
                                    .font(.subheadline.weight(.medium))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 2) // small padding for the scroll indicators
                .padding(.bottom, 8)
            }
            .scrollIndicators(.automatic)
            
            if !isEmbedded {
                HStack {
                    Spacer()
                    Button("Done") {
                        if let onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(isEmbedded ? 10 : 16)
        .frame(width: isEmbedded ? nil : 450, height: isEmbedded ? nil : 360)
        .frame(maxWidth: isEmbedded ? .infinity : nil, maxHeight: isEmbedded ? .infinity : nil, alignment: .topLeading)
        .onAppear {
            refreshAccessibilityPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityPermission()
        }
    }

    private func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AccessibilityManager.checkAccessibility()
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 114, alignment: .leading)
    }

    private var accessibilityStatusBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(hasAccessibilityPermission ? .green : .orange)
            Text(hasAccessibilityPermission ? "已授权" : "未授权")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(hasAccessibilityPermission ? .green : .orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill((hasAccessibilityPermission ? Color.green : Color.orange).opacity(0.12))
        )
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isEmbedded ? 0.65 : 0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct KeyRecorder: View {
    var hotkeyManager: HotkeyManager
    @State private var isRecording = false
    @State private var monitor: Any?
    
    var body: some View {
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
        .buttonStyle(.bordered)
        .tint(isRecording ? .accentColor : .primary.opacity(0.12))
        .controlSize(.small)
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
