import SwiftUI
import AppKit

enum ClipboardItemType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Hashable, Codable {
    var id = UUID()
    let type: ClipboardItemType
    var content: String // For text items, this is the text; for images, this is empty
    let imageData: Data? // PNG data for image items
    let thumbnailData: Data? // Smaller thumbnail for list display
    let date: Date
    
    // Cache for decoded images (not persisted)
    private static var imageCache = NSCache<NSString, NSImage>()
    
    // Hashable conformance for array filtering/diffing
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    // Computed property to get NSImage from imageData with caching
    var image: NSImage? {
        guard type == .image, let data = imageData else { return nil }
        
        let cacheKey = id.uuidString as NSString
        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        if let image = NSImage(data: data) {
            Self.imageCache.setObject(image, forKey: cacheKey)
            return image
        }
        return nil
    }
    
    // Thumbnail for list display with caching
    var thumbnail: NSImage? {
        guard type == .image else { return nil }
        
        let thumbnailCacheKey = "thumb_\(id.uuidString)" as NSString
        if let cachedThumbnail = Self.imageCache.object(forKey: thumbnailCacheKey) {
            return cachedThumbnail
        }
        
        // Try to use thumbnailData first (faster)
        if let thumbData = thumbnailData, let thumb = NSImage(data: thumbData) {
            Self.imageCache.setObject(thumb, forKey: thumbnailCacheKey)
            return thumb
        }
        
        // Fallback to full image if no thumbnail (shouldn't happen with new items)
        return image
    }
    
    // Helper initializer for text items
    init(text: String, date: Date) {
        self.id = UUID()
        self.type = .text
        self.content = text
        self.imageData = nil
        self.thumbnailData = nil
        self.date = date
    }
    
    // Helper initializer for image items with thumbnail generation
    init(image: NSImage, date: Date) {
        self.id = UUID()
        self.type = .image
        self.content = ""
        
        // Store full image data
        self.imageData = image.tiffRepresentation.flatMap { 
            NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
        }
        
        // Generate and store thumbnail (max 160x160 for retina displays)
        let thumbnailSize = NSSize(width: 160, height: 160)
        let thumbnail = Self.createThumbnail(from: image, maxSize: thumbnailSize)
        self.thumbnailData = thumbnail.tiffRepresentation.flatMap { 
            NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
        }
        
        self.date = date
    }
    
    // Helper method to create thumbnail
    private static func createThumbnail(from image: NSImage, maxSize: NSSize) -> NSImage {
        let imageSize = image.size
        guard imageSize.width > maxSize.width || imageSize.height > maxSize.height else {
            return image // No need to resize
        }
        
        let widthRatio = maxSize.width / imageSize.width
        let heightRatio = maxSize.height / imageSize.height
        let scaleFactor = min(widthRatio, heightRatio)
        
        let newSize = NSSize(
            width: imageSize.width * scaleFactor,
            height: imageSize.height * scaleFactor
        )
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: imageSize),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    // Static method to clear image cache (for memory management)
    static func clearImageCache() {
        imageCache.removeAllObjects()
    }
    
    var isJSON: Bool {
        guard type == .text else { return false }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try direct JSON parsing
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data, options: [])) != nil {
                return true
            }
        }
        
        // Try unescaping (e.g. "{\"a\":1}")
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
            // It might be a JSON string that contains serialized JSON
             if let data = trimmed.data(using: .utf8),
                let unescaped = try? JSONSerialization.jsonObject(with: data, options: []) as? String {
                 let unescapedTrimmed = unescaped.trimmingCharacters(in: .whitespacesAndNewlines)
                 if (unescapedTrimmed.hasPrefix("{") && unescapedTrimmed.hasSuffix("}")) ||
                    (unescapedTrimmed.hasPrefix("[") && unescapedTrimmed.hasSuffix("]")) {
                     if let innerData = unescapedTrimmed.data(using: .utf8),
                        (try? JSONSerialization.jsonObject(with: innerData, options: [])) != nil {
                         return true
                     }
                 }
             }
        }
        
        // Try assuming it's the raw content of an escaped JSON string (e.g. [{\"a\":1}])
        // We wrap it in quotes to form a valid JSON string literal and parse that first
        let wrapped = "\"\(trimmed)\""
        if let data = wrapped.data(using: .utf8),
           let unescaped = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? String {
             let unescapedTrimmed = unescaped.trimmingCharacters(in: .whitespacesAndNewlines)
             if (unescapedTrimmed.hasPrefix("{") && unescapedTrimmed.hasSuffix("}")) ||
                (unescapedTrimmed.hasPrefix("[") && unescapedTrimmed.hasSuffix("]")) {
                 if let innerData = unescapedTrimmed.data(using: .utf8),
                    (try? JSONSerialization.jsonObject(with: innerData, options: [])) != nil {
                     return true
                 }
             }
        }
        
        return false
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
            
            // Ignore files (we only want text and images/screenshots)
            if let types = pasteboard.types, types.contains(.fileURL) {
                return
            }
            
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
