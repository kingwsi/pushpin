import SwiftUI

struct ContentView: View {
    @Environment(ClipboardManager.self) private var clipboardManager
    @Environment(\.pasteManager) private var pasteManager
    
    @AppStorage("isPinned") private var isPinned = false
    @State private var showSettings = false
    @State private var hoveredItemId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Add spacer for window controls
            Spacer()
                .frame(height: 12)
            
            if clipboardManager.history.isEmpty {
                ContentUnavailableView("No History", systemImage: "doc.on.clipboard")
            } else {
                List {
                    ForEach(clipboardManager.history) { item in
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
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Material.regular)
        .toolbar {
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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.content)
                        .lineLimit(2)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
}
