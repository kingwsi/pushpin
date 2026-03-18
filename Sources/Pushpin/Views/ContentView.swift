import SwiftUI

struct ContentView: View {
    @Environment(ClipboardManager.self) private var clipboardManager
    @Environment(\.pasteManager) private var pasteManager
    @Environment(\.colorScheme) private var colorScheme
    
    @AppStorage("isPinned") private var isPinned = false
    @State private var showSettings = false
    @State private var showClearConfirmation = false
    @State private var hoveredItemId: UUID?
    @State private var searchText = ""
    @State private var selectedItemId: UUID?
    @Environment(\.openWindow) private var openWindow
    
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
        ZStack {
            mainPanelFace
                .rotation3DEffect(
                    .degrees(showSettings ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.85
                )
                .opacity(showSettings ? 0 : 1)
                .allowsHitTesting(!showSettings)

            settingsPanelFace
                .rotation3DEffect(
                    .degrees(showSettings ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.85
                )
                .opacity(showSettings ? 1 : 0)
                .allowsHitTesting(showSettings)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSettings)
        .background(
            ZStack {
                Rectangle().fill(.regularMaterial)
                Color(NSColor.windowBackgroundColor)
                    .opacity(colorScheme == .dark ? 0.22 : 0.55)
            }
            .ignoresSafeArea(.container, edges: .top)
        )
        .onKeyPress(.escape) {
            if showSettings {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings = false
                }
                return .handled
            }
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
                print("[UI] Return pressed, selected item=\(selectedId)")
                pasteManager.paste(item: item)
                return .handled
            }
            print("[UI] Return pressed, no selected item")
            return .ignored
        }
        .toolbar {
            if !showSettings {
                ToolbarItem(placement: .primaryAction) {
                    ToolbarIconButton(
                        systemImage: "trash",
                        help: "Clear All History",
                        isDisabled: clipboardManager.history.isEmpty
                    ) {
                        showClearConfirmation = true
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    ToolbarIconButton(
                        systemImage: isPinned ? "pin.fill" : "pin",
                        help: "Pin Window"
                    ) {
                        isPinned.toggle()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    ToolbarIconButton(systemImage: "gearshape", help: "Settings") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSettings.toggle()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    ToolbarIconButton(systemImage: "power", help: "Quit (Cmd+Q)") {
                        NSApp.terminate(nil)
                    }
                }
            } else {
                ToolbarItem(placement: .navigation) {
                    ToolbarIconButton(systemImage: "chevron.left", help: "Back") {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showSettings = false
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
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

    private var mainPanelFace: some View {
        VStack(spacing: 0) {
            // Add spacer for window controls
            Spacer()
                .frame(height: 12)
            
            // Search bar
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                    .frame(width: 16, height: 16)
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.78 : 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
            )
            .padding(.leading, 12)
            .padding(.trailing, 26) // 12pt base + ~14pt for scrollbar width
            .padding(.bottom, 10)
            
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
                        LazyVStack(spacing: 10) {
                            ForEach(filteredHistory) { item in
                                ClipboardItemRow(
                                    item: item,
                                    isHovered: hoveredItemId == item.id,
                                    isSelected: selectedItemId == item.id,
                                    onHover: { isHovered in
                                        hoveredItemId = isHovered ? item.id : nil
                                    },
                                    onTap: {
                                        print("[UI] Row tapped, item=\(item.id)")
                                        pasteManager.paste(item: item)
                                    },
                                    onJsonClick: {
                                        openWindow(value: item.id)
                                        // Hide the main panel (identified by being floating)
                                        NSApp.windows.forEach { window in
                                            if window.level == .floating {
                                                window.orderOut(nil)
                                            }
                                        }
                                    }
                                )
                                .equatable()
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settingsPanelFace: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 12)

            SettingsView(isEmbedded: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

struct ClipboardItemRow: View, Equatable {
    let item: ClipboardItem
    let isHovered: Bool
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void
    let onJsonClick: () -> Void
    
    @State private var isButtonHovered = false
    
    // Equatable conformance to reduce unnecessary redraws
    static func == (lhs: ClipboardItemRow, rhs: ClipboardItemRow) -> Bool {
        lhs.item.id == rhs.item.id &&
        lhs.isHovered == rhs.isHovered &&
        lhs.isSelected == rhs.isSelected
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Content based on type
            switch item.type {
            case .text:
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.content)
                        .lineLimit(3)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.72))
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
                
            case .image:
                VStack(alignment: .leading, spacing: 6) {
                    if let thumbnail = item.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .interpolation(.medium)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .drawingGroup() // Enable Metal-accelerated rendering
                    } else {
                        Text("[Image]")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                    }
                    
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.72))
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
            }
            
            Spacer()
            
            if item.isJSON {
                Button(action: onJsonClick) {
                    Text("JSON")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.14))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .opacity(isHovered || isSelected ? 1 : 0.15)
                .help("View/Edit JSON")
            }
            
            // Paste button - visible on hover or selection
            Button(action: onTap) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(isButtonHovered ? 0.9 : 0.7))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(isButtonHovered ? 0.10 : 0.05))
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isSelected ? 1 : 0.45)
            .scaleEffect(isButtonHovered ? 1.04 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: isButtonHovered)
            .frame(width: 30, height: 30)
            .help("Paste item")
            .onHover { hovering in
                isButtonHovered = hovering
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected
                    ? Color.accentColor.opacity(0.20)
                    : (isHovered ? Color(NSColor.controlBackgroundColor).opacity(0.92) : Color(NSColor.controlBackgroundColor).opacity(0.80))
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
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected
                    ? Color.accentColor.opacity(0.70)
                    : Color.primary.opacity(isHovered ? 0.16 : 0.08),
                    lineWidth: isSelected ? 1.2 : 1
                )
        )
    }
}

private struct ToolbarIconButton: View {
    let systemImage: String
    let help: String
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isDisabled ? Color.secondary.opacity(0.5) : Color.primary.opacity(0.85))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered && !isDisabled ? Color.primary.opacity(0.14) : .clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
