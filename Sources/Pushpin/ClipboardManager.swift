import SwiftUI
import AppKit

struct ClipboardItem: Identifiable, Hashable, Codable {
    var id = UUID()
    let content: String
    let date: Date
}

@Observable
class ClipboardManager {
    var history: [ClipboardItem] = [] {
        didSet {
            saveHistory()
        }
    }
    private var lastChangeCount: Int
    private var timer: Timer?
    
    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        loadHistory()
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != lastChangeCount {
            lastChangeCount = pasteboard.changeCount
            
            if let newString = pasteboard.string(forType: .string) {
                // Avoid duplicates at the top
                if let first = history.first, first.content == newString {
                    return
                }
                
                let newItem = ClipboardItem(content: newString, date: Date())
                // Insert at the beginning
                history.insert(newItem, at: 0)
                
                // Limit history size
                if history.count > 50 {
                    history.removeLast()
                }
            }
        }
    }
    
    func clearHistory() {
        history.removeAll()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "ClipboardHistory")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "ClipboardHistory"),
           let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            history = decoded
        }
    }
}
