import AppKit

class AccessibilityManager {
    /// Check if accessibility permission is granted
    static func checkAccessibility() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        return accessEnabled
    }
    
    /// Request accessibility permission (will show system prompt)
    static func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    /// Show custom alert to guide user
    static func showAccessibilityAlert(attachedTo window: NSWindow, onOpenSettings: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        Pushpin 需要辅助功能权限才能自动粘贴内容。
        
        请在"系统设置 > 隐私与安全性 > 辅助功能"中启用 Pushpin。
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后提醒")

        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                onOpenSettings()
            }
        }
    }
    
    /// Open System Settings to Accessibility page
    static func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
