import SwiftUI

struct ContentView: View {
    @Environment(ClipboardManager.self) private var clipboardManager
    @Environment(\.pasteManager) private var pasteManager
    
    @AppStorage("isPinned") private var isPinned = false
    @State private var showSettings = false
    @State private var showClearConfirmation = false
    @State private var hoveredItemId: UUID?
    @State private var searchText = ""
    
    // Filtered history based on search text
    private var filteredHistory: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardManager.history
        } else {
            return clipboardManager.history.filter { item in
                item.content.localizedCaseInsensitiveContains(searchText)
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
                                    onHover: { isHovered in
                                        hoveredItemId = isHovered ? item.id : nil
                                    },
                                    onTap: {
                                        pasteManager.paste(content: item.content)
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        // Scroll to the first item when the view appears
                        if let firstItem = filteredHistory.first {
                            proxy.scrollTo(firstItem.id, anchor: .top)
                        }
                    }
                    .onChange(of: searchText) { _, _ in
                        // Scroll to top when search text changes
                        if let firstItem = filteredHistory.first {
                            withAnimation {
                                proxy.scrollTo(firstItem.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .background(Material.thinMaterial)
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
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon indicator
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.4))
                    .frame(width: 24, height: 24)
                
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
                
                Spacer()
                
                // Hover indicator - always present but opacity controlled
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .opacity(isHovered ? 0.6 : 0)
                    .scaleEffect(isHovered ? 1 : 0.8)
                    .frame(width: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? 
                          Color.primary.opacity(0.12) : 
                          Color.primary.opacity(0.06))
                    .shadow(
                        color: isHovered ? 
                            Color.black.opacity(0.15) : 
                            Color.black.opacity(0.08),
                        radius: isHovered ? 4 : 2,
                        x: 0,
                        y: isHovered ? 2 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                onHover(hovering)
            }
        }
    }
}
