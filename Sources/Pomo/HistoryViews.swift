import Charts
import SwiftUI

struct CheckpointsView: View {
    @ObservedObject var store: TimerStore

    private var sessionsWithCheckpoints: [FocusSession] {
        store.sessions.filter { !$0.checkpoints.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            pageHeader("Checkpoints", detail: "A lightweight trail of decisions and handoff notes.")
                .padding(.horizontal, 34)
            if store.currentCheckpoints.isEmpty && sessionsWithCheckpoints.isEmpty {
                EmptyState(symbol: "flag", title: "No checkpoints yet", detail: "Start a focus timer and save a checkpoint whenever you make a decision or want an easy place to resume.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if !store.currentCheckpoints.isEmpty {
                            checkpointGroup(title: "Current session", date: Date(), checkpoints: store.currentCheckpoints, tint: store.phase.color)
                        }
                        ForEach(sessionsWithCheckpoints) { session in
                            checkpointGroup(
                                title: session.task.isEmpty ? "Untitled focus" : session.task,
                                date: session.endedAt,
                                checkpoints: session.checkpoints,
                                tint: .secondary
                            )
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func checkpointGroup(title: String, date: Date, checkpoints: [Checkpoint], tint: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    Spacer()
                    Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(checkpoints) { checkpoint in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(tint).frame(width: 8, height: 8)
                            Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1).frame(maxHeight: .infinity)
                        }
                        .frame(width: 10)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(checkpoint.note)
                            Text("At \(checkpoint.elapsedSeconds.clockString)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct StatisticsView: View {
    @ObservedObject var store: TimerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader("Statistics", detail: "Private, local, and useful enough to guide the next day.")

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    MetricCard(title: "Today", value: store.focusedSecondsToday.compactDuration, detail: "focused", symbol: "sun.max", tint: .orange)
                    MetricCard(title: "This week", value: store.focusedSecondsThisWeek.compactDuration, detail: "focused", symbol: "calendar", tint: .blue)
                    MetricCard(title: "Sessions", value: "\(store.completedFocusCountToday)", detail: "completed today", symbol: "checkmark.circle", tint: .green)
                    MetricCard(title: "Streak", value: "\(store.currentStreak)", detail: store.currentStreak == 1 ? "day" : "days", symbol: "flame", tint: .red)
                }

                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Last 7 days").font(.headline)
                            Text("Minutes of focused work").font(.caption).foregroundStyle(.secondary)
                        }
                        Chart(store.lastSevenDays) { day in
                            BarMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Minutes", day.seconds / 60)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(5)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                AxisValueLabel(format: .dateTime.weekday(.narrow))
                                AxisGridLine().foregroundStyle(.clear)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 190)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent sessions").font(.headline)
                    if store.sessions.isEmpty {
                        Card {
                            Text("Completed and early-finished focus sessions will appear here.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        ForEach(store.sessions.prefix(12)) { session in
                            Card {
                                HStack(spacing: 14) {
                                    Image(systemName: session.completed ? "checkmark.circle.fill" : "stop.circle")
                                        .foregroundStyle(session.completed ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.task.isEmpty ? "Untitled focus" : session.task)
                                            .font(.callout.weight(.medium))
                                        Text(session.endedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !session.checkpoints.isEmpty {
                                        Label("\(session.checkpoints.count)", systemImage: "flag")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Text(session.focusedSeconds.compactDuration)
                                        .font(.callout.monospacedDigit().weight(.medium))
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 34)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SettingsView: View {
    @ObservedObject var store: TimerStore
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                pageHeader("Settings", detail: "Shape a rhythm that fits the work in front of you.")

                settingsCard("Durations", symbol: "clock") {
                    durationRow("Focus", value: $store.settings.focusMinutes, range: 1...120, tint: TimerPhase.focus.color)
                    Divider()
                    durationRow("Enforced break", value: $store.settings.breakMinutes, range: 1...60, tint: TimerPhase.breakTime.color)
                }

                settingsCard("Routine", symbol: "repeat") {
                    Stepper(value: $store.settings.dailyGoalMinutes, in: 15...600, step: 15) {
                        settingsLabel("Daily focus goal", detail: "\(store.settings.dailyGoalMinutes) minutes")
                    }
                    Divider()
                    Toggle(isOn: $store.settings.playSound) {
                        settingsLabel("Completion sound", detail: "Play a system sound when time is up")
                    }
                }

                settingsCard("Local data", symbol: "internaldrive") {
                    HStack {
                        settingsLabel("Session history", detail: "Stored only in this Mac user account")
                        Spacer()
                        Button("Clear history", role: .destructive) { showClearConfirmation = true }
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 34)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Clear all session history?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { store.clearHistory() }
        } message: {
            Text("This permanently removes saved sessions, checkpoints, and statistics from this Mac.")
        }
    }

    private func settingsCard<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: symbol).font(.headline)
                content()
            }
        }
    }

    private func durationRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, tint: Color) -> some View {
        HStack {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue) min").monospacedDigit().frame(width: 58, alignment: .trailing)
            }
            .fixedSize()
        }
    }

    private func settingsLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

}

@ViewBuilder
func pageHeader(_ title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.system(size: 28, weight: .semibold, design: .rounded))
        Text(detail).font(.callout).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 30)
    .padding(.bottom, 24)
}
