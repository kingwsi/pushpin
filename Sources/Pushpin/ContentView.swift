import SwiftUI

struct ContentView: View {
    @Environment(ClipboardManager.self) private var clipboardManager
    @Environment(\.pasteManager) private var pasteManager
    
    @AppStorage("isPinned") private var isPinned = false
    @State private var showSettings = false
    @State private var showClearConfirmation = false
    @State private var hoveredItemId: UUID?
    @State private var searchText = ""
    @State private var selectedItemId: UUID?
    
    // Filtered history based on search text
    private var filteredHistory: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.history
        } else {
            return clipboardManager.history.filter { item in
                switch item.type {
                case .text:
                    return item.content.localizedCaseInsensitiveContains(searchText)
                case .image:
                    // Allow searching for images by typing "image"
                    return "image".localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Add spacer for window controls
            Spacer()
                .frame(height: 12)
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.45))
                    .frame(width: 16, height: 16)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.primary.opacity(0.4))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.08))
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            )
            .padding(.leading, 12)
            .padding(.trailing, 27) // 12pt base + ~15pt for scrollbar width
            .padding(.bottom, 8)
            
            if filteredHistory.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("No History", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No clipboard items match '\(searchText)'"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredHistory) { item in
                                ClipboardItemRow(
                                    item: item,
                                    isHovered: hoveredItemId == item.id,
                                    isSelected: selectedItemId == item.id,
                                    onHover: { isHovered in
                                        hoveredItemId = isHovered ? item.id : nil
                                    },
                                    onTap: {
                                        pasteManager.paste(item: item)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .scrollPosition(id: $selectedItemId, anchor: .center) // iOS 17/macOS 14+ API for simpler scrolling
                    .onAppear {
                        // Scroll to the first item when the view appears
                        if let firstItem = filteredHistory.first {
                            selectedItemId = firstItem.id
                        }
                    }
                    .onChange(of: searchText) { _, _ in
                        // Reset selection when search changes
                        if let firstItem = filteredHistory.first {
                            selectedItemId = firstItem.id
                        } else {
                            selectedItemId = nil
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                         // Always select the first item when window becomes active
                        if let firstItem = filteredHistory.first {
                            selectedItemId = firstItem.id
                        }
                    }
                }
            }
        }
        .background(Material.thinMaterial)
        .onKeyPress(.escape) {
            if !searchText.isEmpty {
                searchText = ""
                return .handled
            }
            if let window = NSApp.windows.first {
                window.orderOut(nil)
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(direction: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if let selectedId = selectedItemId, 
               let item = clipboardManager.history.first(where: { $0.id == selectedId }) {
                pasteManager.paste(item: item)
                return .handled
            }
            return .ignored
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showClearConfirmation = true }) {
                    Image(systemName: "trash")
                }
                .help("Clear All History")
                .disabled(clipboardManager.history.isEmpty)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isPinned.toggle() }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                }
                .help("Pin Window")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
                .help("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .confirmationDialog("Clear All History", isPresented: $showClearConfirmation) {
            Button("Clear All", role: .destructive) {
                clipboardManager.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear all clipboard history? This action cannot be undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if !isPinned {
                // Close window instead of hiding app
                if let window = NSApp.windows.first {
                    window.orderOut(nil)
                }
            }
        }
    }
    
    private func moveSelection(direction: Int) {
        let history = filteredHistory
        guard !history.isEmpty else { return }
        
        // If nothing selected, select first
        guard let currentId = selectedItemId, 
              let currentIndex = history.firstIndex(where: { $0.id == currentId }) else {
            selectedItemId = history.first?.id
            return
        }
        
        let newIndex = currentIndex + direction
        if newIndex >= 0 && newIndex < history.count {
            selectedItemId = history[newIndex].id
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    
    @State private var isButtonHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Content based on type
            switch item.type {
            case .text:
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.content)
                        .lineLimit(2)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.45))
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                
            case .image:
                VStack(alignment: .leading, spacing: 6) {
                    if let image = item.image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    } else {
                        Text("[Image]")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.45))
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
            }
            
            Spacer()
            
            // Paste button - visible on hover or selection
            Button(action: onTap) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 16))
                    .foregroundStyle(isButtonHovered ? Color.secondary : Color.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isSelected ? 1 : 0)
            .scaleEffect(isButtonHovered ? 1.1 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isButtonHovered)
            .frame(width: 24, height: 24)
            .help("Paste item")
            .onHover { hovering in
                isButtonHovered = hovering
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) :
                      (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.06)))
                .shadow(
                    color: (isHovered || isSelected) ?
                        Color.black.opacity(0.15) :
                        Color.black.opacity(0.08),
                    radius: (isHovered || isSelected) ? 4 : 2,
                    x: 0,
                    y: (isHovered || isSelected) ? 2 : 1
                )
        )
        // Make the whole background tappable for paste
        .onTapGesture { onTap() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                onHover(hovering)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(isSelected ? 0.5 : 0), lineWidth: 1)
        )
    }
}

