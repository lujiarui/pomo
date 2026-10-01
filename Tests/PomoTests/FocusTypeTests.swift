import Foundation
import Testing
@testable import Pomo

struct FocusTypeTests {
    @Test func emojiValidationHandlesComposedCharactersAndRejectsText() {
        for emoji in ["🔬", "🐭", "👩🏽‍💻", "🇨🇳", "🏳️‍🌈", "1️⃣", "❤️", "  🎨  "] {
            #expect(FocusTypeAppearance.isSingleEmoji(emoji))
        }
        for text in ["", " ", "A", "1", "Research", "🐭🎨"] {
            #expect(!FocusTypeAppearance.isSingleEmoji(text))
        }
    }

    @Test func builtInTypesHaveDistinctIconsAndNoFocusTypeUsesGreen() {
        let names = FocusTypeAppearance.builtInNames
        #expect(Set(names.map(FocusTypeAppearance.symbol)).count == names.count)
        #expect(Set(names.map { FocusTypeAppearance.standard(for: $0).color }).count == names.count)
        for color in FocusTypeColor.allCases {
            let rgb = color.components
            #expect(rgb.red > rgb.green || rgb.blue > rgb.green)
        }
    }

    @Test @MainActor func legacyTypesLoadAndCustomAppearancePersistsAcrossEdits() throws {
        let suite = "pomo.type.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["Research", "Exercise"], forKey: "pomo.categories.v1")
        let date = Date()
        let session = FocusSession(startedAt: date, endedAt: date.addingTimeInterval(120),
                                   plannedSeconds: 1500, focusedSeconds: 120, task: "Paper",
                                   checkpoints: [], completed: false, category: "Research")
        defaults.set(try JSONEncoder().encode([session]), forKey: "pomo.sessions.v1")
        let store = TimerStore(defaults: defaults)
        #expect(store.categories.contains("Exercise"))
        #expect(store.categoryAppearance("Research").emoji == "✨")
        #expect(store.selectCustomCategory(" research ", emoji: " 👩🏽‍💻 ", color: .blue))
        #expect(store.category == "Research")
        #expect(store.selectCustomCategory("Research", emoji: "🔬", color: .plum))
        let restored = TimerStore(defaults: defaults)
        #expect(restored.categoryAppearance("Research") == FocusTypeAppearance(emoji: "🔬", color: .plum))
        #expect(restored.categories.filter { $0 == "Research" }.count == 1)
        #expect(restored.sessions == [session])
        #expect(restored.categoryColor(restored.sessions[0].category) == FocusTypeColor.plum.color)
        // Built-in appearances cannot be overwritten by a duplicate custom name.
        store.selectCustomCategory("focus", emoji: "🐭", color: .purple)
        #expect(store.categoryAppearance("Focus") == .standard(for: "Focus"))
    }

    @Test @MainActor func invalidOrInFlightEditsLeaveAttributionAndBreakGreenIntact() throws {
        let suite = "pomo.type.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date()
        let store = TimerStore(defaults: defaults, now: { date })
        #expect(!store.selectCustomCategory("Invalid", emoji: "abc", color: .pink))
        #expect(!store.categories.contains("Invalid"))
        #expect(store.category == "Focus")
        store.selectCustomCategory("Research", emoji: "🔬", color: .purple)
        #expect(store.currentTint == FocusTypeColor.purple.color)
        store.start()
        date += 30
        store.pause()
        let remaining = store.remainingSeconds
        #expect(!store.selectCustomCategory("Research", emoji: "🎨", color: .orange))
        #expect(store.remainingSeconds == remaining)
        #expect(store.categoryAppearance("Research").color == .purple)
        store.finishEarly()
        #expect(store.phase == .breakTime)
        #expect(store.currentTint == TimerPhase.breakTime.color)
        #expect(store.sessions.first?.category == "Research")
        #expect(!store.selectCustomCategory("Other", emoji: "🎨", color: .pink))
        #expect(store.currentTint == TimerPhase.breakTime.color)
        store.skipBreak()
        #expect(store.currentTint == FocusTypeColor.purple.color)
    }
}
