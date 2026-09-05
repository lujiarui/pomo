import SwiftUI

struct TimerView: View {
    @ObservedObject var store: TimerStore
    @FocusState private var checkpointFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                cycleHint
                timerRing
                taskArea
                controls
                checkpointComposer
                todayProgress
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 42)
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.handleAppBecameActive()
        }
    }

    private var cycleHint: some View {
        HStack(spacing: 11) {
            Label("Focus \(store.settings.focusMinutes)m", systemImage: "scope")
                .foregroundStyle(TimerPhase.focus.color)
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.tertiary)
            Label("Break \(store.settings.breakMinutes)m", systemImage: "cup.and.heat.waves")
                .foregroundStyle(TimerPhase.breakTime.color)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 15)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(0.04), in: Capsule())
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(store.phase.color.opacity(0.12), lineWidth: 10)
            Circle()
                .trim(from: 0, to: store.progress)
                .stroke(store.phase.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.2), value: store.progress)
            VStack(spacing: 8) {
                Text(store.phase.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(store.phase.color)
                Text(store.remainingSeconds.clockString)
                    .font(.system(size: 63, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(timerDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 276, height: 276)
        .padding(.vertical, 4)
    }

    private var timerDetail: String {
        if store.phase == .breakTime { return "Step away. Focus resumes when you choose." }
        if store.isRunning { return "Stay with this moment" }
        if store.elapsedSeconds > 0 { return "Paused" }
        return "Ready when you are"
    }

    @ViewBuilder
    private var taskArea: some View {
        if store.phase == .focus {
            HStack(spacing: 10) {
                Image(systemName: "scope").foregroundStyle(TimerPhase.focus.color)
                TextField("What are you focusing on?", text: $store.task)
                    .textFieldStyle(.plain)
                    .font(.body.weight(.medium))
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        } else {
            Label("Your work block is saved. Leave the screen for a moment.", systemImage: "checkmark.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if store.phase == .focus {
            HStack(spacing: 12) {
                Button {
                    store.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 42, height: 42)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .help("Reset timer")

                Button {
                    store.toggleTimer()
                } label: {
                    Label(store.isRunning ? "Pause" : "Start", systemImage: store.isRunning ? "pause.fill" : "play.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 130, height: 36)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .tint(TimerPhase.focus.color)

                Button {
                    store.finishEarly()
                } label: {
                    Image(systemName: "cup.and.heat.waves").frame(width: 42, height: 42)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .disabled(store.elapsedSeconds == 0)
                .help("Stop work, save a checkpoint, and start your break")
            }
        } else {
            VStack(spacing: 9) {
                Button("Skip break") { store.skipBreak() }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                Text("Skipping returns to a paused focus timer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var checkpointComposer: some View {
        Card {
            if store.phase == .focus {
                VStack(alignment: .leading, spacing: 11) {
                    Label("End-of-focus checkpoint", systemImage: "flag")
                        .font(.callout.weight(.semibold))
                    TextField("Where should you resume? (optional)", text: $store.checkpointDraft)
                        .textFieldStyle(.plain)
                        .focused($checkpointFocused)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                    Text("This note is saved automatically when focus ends or you choose to take a break.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label("Checkpoint saved", systemImage: "flag.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(TimerPhase.breakTime.color)
                        Spacer()
                        if let latest = store.latestCheckpoint {
                            Text(latest.elapsedSeconds.clockString)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let latest = store.latestCheckpoint {
                        Text(latest.note).font(.callout)
                    }
                    HStack(spacing: 8) {
                        TextField("Add a resume note", text: $store.checkpointDraft)
                            .textFieldStyle(.plain)
                            .focused($checkpointFocused)
                            .onSubmit { store.addCheckpoint() }
                        Button("Save") { store.addCheckpoint() }
                            .buttonStyle(.bordered)
                            .disabled(store.checkpointDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var todayProgress: some View {
        let goal = max(1, store.settings.dailyGoalMinutes * 60)
        return VStack(spacing: 8) {
            HStack {
                Text("Today").font(.caption.weight(.semibold))
                Spacer()
                Text("\(store.focusedSecondsToday.compactDuration) of \(goal.compactDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, Double(store.focusedSecondsToday) / Double(goal)))
                .tint(store.phase.color)
        }
    }
}
