import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                Text(value)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Int {
    var clockString: String {
        String(format: "%02d:%02d", self / 60, self % 60)
    }

    var compactDuration: String {
        if self < 60 { return "\(self)s" }
        let minutes = self / 60
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 { return "\(hours)h \(remainder)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}

enum ActivityColors {
    static func task(_ name: String) -> Color {
        let hash = name.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return Color(hue: Double(hash % 997) / 997, saturation: 0.65, brightness: 0.85)
    }

    static func allocation(_ name: String, grouping: AllocationGrouping, index: Int) -> Color {
        if grouping == .category { return FocusTypeAppearance.standard(for: name).color.color }
        let palette: [Color] = [.blue, .purple, .teal, .orange, .pink, .indigo, .green, .red, .cyan, .brown]
        if index < palette.count { return palette[index] }
        return Color(hue: (Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 0.85)
    }
}

struct FocusActionButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.4)
    }
}

struct CategoryPicker: View {
    @ObservedObject var store: TimerStore
    @State private var showsEditor = false
    @State private var editingCategory: String?

    var body: some View {
        Menu {
            ForEach(store.categories, id: \.self) { name in
                Button {
                    store.category = name
                } label: {
                    let appearance = store.categoryAppearance(name)
                    if let emoji = appearance.emoji {
                        Text("\(emoji)  \(name)\(name == store.category ? "  ✓" : "")")
                    } else {
                        Label("\(name)\(name == store.category ? "  ✓" : "")", systemImage: FocusTypeAppearance.symbol(for: name))
                    }
                }
            }
            Divider()
            Button {
                editingCategory = nil
                showsEditor = true
            } label: {
                Label("New type…", systemImage: "plus.circle")
            }
            if !FocusTypeAppearance.builtInNames.contains(store.category) {
                Button {
                    editingCategory = store.category
                    showsEditor = true
                } label: {
                    Label("Edit icon & color…", systemImage: "paintpalette")
                }
            }
        } label: {
            HStack(spacing: 8) {
                FocusTypeIcon(name: store.category, appearance: store.categoryAppearance(store.category))
                    .frame(width: 18)
                Text(store.category)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(store.categoryColor(store.category))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(!store.canEditTask)
        .accessibilityLabel("Type: \(store.category)")
        .help(store.canEditTask ? "Choose a type, or add a custom type" : "Choose the task and type before starting a new block")
        .sheet(isPresented: $showsEditor) {
            FocusTypeEditor(store: store, editingCategory: editingCategory)
        }
    }
}

struct FocusTypeEditor: View {
    @ObservedObject var store: TimerStore
    let editingCategory: String?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var color: FocusTypeColor

    init(store: TimerStore, editingCategory: String? = nil) {
        self.store = store
        self.editingCategory = editingCategory
        let appearance = store.categoryAppearance(editingCategory ?? "")
        _name = State(initialValue: editingCategory ?? "")
        _emoji = State(initialValue: appearance.emoji ?? "✨")
        _color = State(initialValue: editingCategory == nil ? .purple : appearance.color)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var validEmoji: Bool { FocusTypeAppearance.isSingleEmoji(emoji) }
    private var duplicateName: Bool {
        editingCategory == nil && store.categories.contains { $0.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(editingCategory == nil ? "New type" : "Edit type")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 7) {
                Text("Name").font(.callout.weight(.medium))
                TextField("e.g. Research or Exercise", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(editingCategory != nil)
                if duplicateName {
                    Text("This type already exists.").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Emoji icon").font(.callout.weight(.medium))
                HStack(spacing: 9) {
                    TextField("✨", text: $emoji)
                        .font(.system(size: 24))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                        .accessibilityLabel("Emoji icon")
                    ForEach(["🔬", "💻", "🎨", "🎯", "📚", "🐭"], id: \.self) { suggestion in
                        Button(suggestion) { emoji = suggestion }
                            .font(.system(size: 20))
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use \(suggestion)")
                    }
                }
                Text(validEmoji ? "Paste an emoji or choose one above." : "Use one emoji for the icon.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Color · \(color.title)").font(.callout.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(FocusTypeColor.allCases) { option in
                        Button { color = option } label: {
                            Circle().fill(option.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if color == option {
                                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                    }
                                }
                                .padding(3)
                                .overlay { Circle().stroke(color == option ? option.color : .clear, lineWidth: 1.5) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(color == option ? .isSelected : [])
                        .help(option.title)
                    }
                }
                Text("Green is reserved for Break.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 9) {
                FocusTypeIcon(name: trimmedName, appearance: FocusTypeAppearance(emoji: emoji, color: color))
                Text(trimmedName.isEmpty ? "Your type" : trimmedName)
                    .font(.callout.weight(.semibold)).lineLimit(1)
                Spacer()
                Image(systemName: "play.fill")
            }
            .foregroundStyle(color.color)
            .padding(12)
            .background(color.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(editingCategory == nil ? "Add" : "Save") {
                    if store.selectCustomCategory(trimmedName, emoji: emoji, color: color) { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(FocusActionButtonStyle(tint: color.color))
                .disabled(trimmedName.isEmpty || !validEmoji || duplicateName || !store.canEditTask)
            }
        }
        .padding(24)
        .frame(width: 392)
    }
}
