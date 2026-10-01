import SwiftUI

/// Green is reserved for breaks, so focus types use this separate palette.
enum FocusTypeColor: String, Codable, CaseIterable, Identifiable {
    case coral, blue, purple, orange, pink, indigo, sky, plum

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var color: Color {
        let rgb = components
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    var components: (red: Double, green: Double, blue: Double) {
        switch self {
        case .coral: (0.93, 0.36, 0.31)
        case .blue: (0.20, 0.46, 0.90)
        case .purple: (0.64, 0.30, 0.88)
        case .orange: (0.91, 0.48, 0.15)
        case .pink: (0.88, 0.28, 0.53)
        case .indigo: (0.39, 0.36, 0.82)
        case .sky: (0.16, 0.53, 0.80)
        case .plum: (0.66, 0.28, 0.63)
        }
    }
}

struct FocusTypeAppearance: Codable, Equatable {
    var emoji: String?
    var color: FocusTypeColor

    static let builtInNames = ["Focus", "Work", "Study", "Creative", "Personal"]

    static func standard(for name: String) -> Self {
        switch name {
        case "Focus": return Self(color: .coral)
        case "Work": return Self(color: .blue)
        case "Study": return Self(color: .purple)
        case "Creative": return Self(color: .orange)
        case "Personal": return Self(color: .pink)
        default:
            let hash = name.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
            return Self(emoji: "✨", color: FocusTypeColor.allCases[Int(hash % UInt64(FocusTypeColor.allCases.count))])
        }
    }

    static func symbol(for name: String) -> String {
        switch name {
        case "Focus": "scope"
        case "Work": "briefcase.fill"
        case "Study": "book.closed.fill"
        case "Creative": "paintbrush.pointed.fill"
        case "Personal": "person.fill"
        default: "tag.fill"
        }
    }

    static func isSingleEmoji(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1 else { return false }
        // Emoji sequences include flags, skin tones, keycaps and joined characters.
        return trimmed.unicodeScalars.contains { $0.properties.isEmojiPresentation }
            || (trimmed.unicodeScalars.contains { $0.properties.isEmoji }
                && trimmed.unicodeScalars.contains { $0.value == 0xFE0F || $0.value == 0x20E3 })
    }
}

struct FocusTypeIcon: View {
    let name: String
    let appearance: FocusTypeAppearance

    var body: some View {
        Group {
            if let emoji = appearance.emoji {
                Text(emoji)
            } else {
                Image(systemName: FocusTypeAppearance.symbol(for: name))
            }
        }
        .foregroundStyle(appearance.color.color)
        .accessibilityHidden(true)
    }
}
