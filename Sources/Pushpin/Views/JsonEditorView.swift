import SwiftUI
import AppKit

struct JsonEditorView: View {
    @Binding var text: String
    
    var body: some View {
        JsonTextView(text: $text, findTrigger: $findTrigger)
            .frame(minWidth: 500, minHeight: 400)
            .background(Color(NSColor.textBackgroundColor))
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: formatJson) {
                        Label("Format JSON", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help("Format JSON")
                }
            }
            .onAppear {
                formatJson()
            }
            // Capture Command+F to trigger find
            // Capture Command+F to trigger find
            .onKeyPress(keys: [.init("f")]) { press in
                if press.modifiers.contains(.command) {
                    findTrigger.toggle()
                    return .handled
                }
                return .ignored
            }
    }
    
    @State private var findTrigger = false
    
    private func formatJson() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8) {
            // First try direct parsing
            if let json = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                text = prettyString
                return
            }
            
            // Try unescaping if it looks like an escaped string (quoted)
            if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
                if let unescaped = try? JSONSerialization.jsonObject(with: data, options: []) as? String,
                   let innerData = unescaped.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: innerData, options: []),
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    text = prettyString
                    return
                }
            }
            
            // Try unescaping if it looks like raw escaped content (e.g. [{\"a\":1}])
            let wrapped = "\"\(trimmed)\""
            if let wrappedData = wrapped.data(using: .utf8),
               let unescaped = try? JSONSerialization.jsonObject(with: wrappedData, options: [.fragmentsAllowed]) as? String,
               let innerData = unescaped.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: innerData, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                text = prettyString
                return
            }
        }
    }
}

struct JsonTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var findTrigger: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        
        let textView = NSTextView()
        textView.isRichText = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.delegate = context.coordinator
        
        // Setup layout manager and text storage
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        
        // Find configuration
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        
        // Good defaults for code editing
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if findTrigger {
            // Reset trigger async to avoid loop
            DispatchQueue.main.async {
                self.findTrigger = false
                // Tag 1 is NSFindPanelAction.showFindPanel (which shows the bar if usesFindBar is true)
                let tempItem = NSMenuItem(title: "Find", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "")
                tempItem.tag = 1 // NSFindPanelAction.showFindPanel
                textView.performFindPanelAction(tempItem)
            }
        }
        
        if textView.string != text {
            // Keep selection if possible
            let selectedRanges = textView.selectedRanges
            textView.string = text
            context.coordinator.highlight(textView: textView)
            // Restore selection if valid
            if let first = selectedRanges.first as? NSRange, first.upperBound <= text.count {
                textView.selectedRanges = selectedRanges
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JsonTextView
        var isHighlighting = false

        init(_ parent: JsonTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Avoid infinite loop if we change text inside processing (though we only change attributes)
            parent.text = textView.string
            highlight(textView: textView)
        }
        
        func highlight(textView: NSTextView) {
            guard !isHighlighting else { return }
            isHighlighting = true
            defer { isHighlighting = false }
            
            let text = textView.string
            let textStorage = textView.textStorage
            let range = NSRange(location: 0, length: text.utf16.count)
            
            textStorage?.beginEditing()
            
            // Reset connection to default
            textStorage?.setAttributes([
                .foregroundColor: NSColor.textColor,
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ], range: range)

            // Simple regex for JSON
            let stringPattern = "\"(\\\\.|[^\"\\\\])*\""
            let keyPattern = "\"(\\\\.|[^\"\\\\])*\"(?=\\s*:)"
            let numberPattern = "-?\\b\\d+(\\.\\d+)?([eE][+-]?\\d+)?\\b"
            let boolPattern = "\\b(true|false|null)\\b"
            
            func apply(pattern: String, color: NSColor) {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let matchRange = match?.range {
                        textStorage?.addAttribute(.foregroundColor, value: color, range: matchRange)
                    }
                }
            }
            
            // Order matters
            apply(pattern: stringPattern, color: NSColor.systemGreen) // Strings
            apply(pattern: keyPattern, color: NSColor.systemBlue)    // Keys
            apply(pattern: numberPattern, color: NSColor.systemOrange) // Numbers
            apply(pattern: boolPattern, color: NSColor.systemPurple)   // Booleans/Null
            
            textStorage?.endEditing()
        }
    }
}
