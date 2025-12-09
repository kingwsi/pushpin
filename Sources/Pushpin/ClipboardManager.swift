import SwiftUI
import AppKit

enum ClipboardItemType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Hashable, Codable {
    var id = UUID()
    let type: ClipboardItemType
    let content: String // For text items, this is the text; for images, this is empty
    let imageData: Data? // PNG data for image items
    let date: Date
    
    // Hashable conformance for array filtering/diffing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // Computed property to get NSImage from imageData
    var image: NSImage? {
        guard type == .image, let data = imageData else { return nil }
        return NSImage(data: data)
    }
    
    // Helper initializer for text items
    init(text: String, date: Date) {
        self.id = UUID()
        self.type = .text
        self.content = text
        self.imageData = nil
        self.date = date
    }
    
    // Helper initializer for image items
    init(image: NSImage, date: Date) {
        self.id = UUID()
        self.type = .image
        self.content = ""
        self.imageData = image.tiffRepresentation.flatMap { 
            NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
        }
        self.date = date
    }
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
    
    // Maximum number of items to keep in history (configurable)
    var maxHistoryCount: Int {
        let stored = UserDefaults.standard.integer(forKey: "MaxHistoryCount")
        return stored > 0 ? stored : 50 // Default to 50 if not set
    }
    
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
            
            // Check for image first (higher priority)
            if let image = NSImage(pasteboard: pasteboard) {
                // Avoid duplicates at the top
                if let first = history.first, first.type == .image, 
                   let firstImageData = first.imageData,
                   let newImageData = image.tiffRepresentation.flatMap({ 
                       NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
                   }),
                   firstImageData == newImageData {
                    return
                }
                
                let newItem = ClipboardItem(image: image, date: Date())
                history.insert(newItem, at: 0)
                
                // Limit history size based on user setting
                trimHistoryIfNeeded()
            }
            // Then check for text
            else if let newString = pasteboard.string(forType: .string) {
                // Avoid duplicates at the top
                if let first = history.first, first.type == .text, first.content == newString {
                    return
                }
                
                let newItem = ClipboardItem(text: newString, date: Date())
                history.insert(newItem, at: 0)
                
                // Limit history size based on user setting
                trimHistoryIfNeeded()
            }
        }
    }
    
    private func trimHistoryIfNeeded() {
        let maxCount = maxHistoryCount
        if history.count > maxCount {
            history.removeSubrange(maxCount...)
        }
    }
    
    // Public method to trim history (called from settings when max count changes)
    func trimHistory() {
        trimHistoryIfNeeded()
    }
    
    func clearHistory() {
        history.removeAll()
    }
    
    func deleteItem(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
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
