import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: TimerStore
    let openMain: () -> Void
    @FocusState private var checkpointFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack {
                    Label(store.phase.title, systemImage: store.phase == .focus ? "scope" : "cup.and.heat.waves")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(store.phase.color)
                    Spacer()
                    Text(statusLabel)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    Text(store.remainingSeconds.clockString)
                        .font(.system(size: 46, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    ProgressView(value: store.progress)
                        .tint(store.phase.color)
                }

                if store.phase == .focus {
                    TextField("What are you focusing on?", text: $store.task)
                        .textFieldStyle(.plain)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 9) {
                        Button {
                            store.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise").frame(width: 32, height: 32)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)

                        Button {
                            store.toggleTimer()
                        } label: {
                            Label(store.isRunning ? "Pause" : "Start", systemImage: store.isRunning ? "pause.fill" : "play.fill")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(TimerPhase.focus.color)

                        Button {
                            store.finishEarly()
                        } label: {
                            Image(systemName: "cup.and.heat.waves").frame(width: 32, height: 32)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .disabled(store.elapsedSeconds == 0)
                        .help("Stop work and begin break")
                    }
                } else {
                    Label("Your checkpoint is saved. Take the whole break if you can.", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Skip break") { store.skipBreak() }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                }
            }
            .padding(16)

            Divider()

            checkpointArea

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                    Text("\(store.focusedSecondsToday.compactDuration) · \(store.completedFocusCountToday) sessions")
                        .font(.caption)
                }
                Spacer()
                Button("Open Pomo") { openMain() }
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .frame(width: 322)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var checkpointArea: some View {
        VStack(alignment: .leading, spacing: 9) {
            if store.phase == .focus {
                if !store.breakNotesForNextFocus.isEmpty {
                    Label("Notes from your break", systemImage: "note.text")
                        .font(.caption.weight(.semibold))
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(store.breakNotesForNextFocus) { note in
                                HStack(alignment: .top, spacing: 7) {
                                    Circle()
                                        .fill(TimerPhase.breakTime.color)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 5)
                                    Text(note.note)
                                        .font(.caption)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 92)
                    Divider()
                }
                Label("End-of-focus checkpoint", systemImage: "flag")
                    .font(.caption.weight(.semibold))
                TextField("Where should you resume?", text: $store.checkpointDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($checkpointFocused)
                Text("Saved automatically when focus ends.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack {
                    Label("Checkpoint saved", systemImage: "flag.fill")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    if let latest = store.latestCheckpoint {
                        Text(latest.elapsedSeconds.clockString)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                if let latest = store.latestCheckpoint {
                    Text(latest.note).font(.caption).lineLimit(1)
                }
                HStack(spacing: 7) {
                    TextField("Add a resume note", text: $store.checkpointDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($checkpointFocused)
                        .onSubmit { store.addCheckpoint() }
                    Button {
                        store.addCheckpoint()
                    } label: {
                        Image(systemName: "flag.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TimerPhase.breakTime.color)
                    .disabled(store.checkpointDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(14)
        .onAppear {
            if store.phase == .breakTime { checkpointFocused = true }
        }
    }

    private var statusLabel: String {
        if store.phase == .breakTime { return "BREAKING" }
        if store.isRunning { return "RUNNING" }
        return store.elapsedSeconds > 0 ? "PAUSED" : "READY"
    }
}
