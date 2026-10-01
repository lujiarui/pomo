# Pomo

A minimalist, native Pomodoro timer for macOS. Pomo keeps its data local and helps you leave a small trail of checkpoints while you work.

## Run

Pomo requires macOS 14 or later and Apple Command Line Tools with Swift 6.2 or later. Build a normal macOS app bundle with:

```sh
./scripts/build_app.sh
open build/Pomo.app
```

For development, you can also run the Swift package directly:

```sh
swift run Pomo
```

## Features

- One adjustable focus duration and one enforced break duration
- Timer accuracy while the app is in the background
- Automatic checkpoints when focus ends or work is stopped, plus resume notes during breaks
- Local daily/weekly statistics, 7-day chart, goals, and streaks
- Switch focus types (default: Focus) in the timer header and upper-left menu bar header, with a distinct icon for each built-in type
- Custom types support an emoji icon and an eight-color palette; the timer, Start button, and type charts share that color. Green stays reserved for Break
- Daily time allocation by type or task, with pie/bar views, durations, and percentages
- Date-selectable timeline with a full-day chart and chronological activity details
- Live statistics include the current block; pauses are excluded and cross-midnight work is split by day
- Breaks start automatically; finishing or skipping one returns to a stopped next-focus timer
- Completion notifications and sound
- Persistent menu bar countdown that automatically opens its break window at every focus boundary
- Five selectable animated pixel break buddies (Mochi, Bun, Sprout, Byte, Pip the mouse), shown beside the break window
- Short Chinese break reminders rotate every 12 seconds; buddy selection is saved locally
- A static chibi avatar of the selected buddy appears in the focus timer and menu bar panel

Session history and settings are stored in macOS `UserDefaults` for the current user. No account, network connection, or analytics are used.

The main window appears at launch. Closing it keeps Pomo running in the menu bar; starting, pausing, or ending focus and breaks does not reopen or minimize the main window. Use **Open Pomo** in the timer panel, or click the Dock icon, to open it again.

Use the type menu to add a custom type or edit its icon and color. Type names stay fixed when editing so existing history keeps its attribution.

Choose a task and type before starting a focus block; they stay fixed until the next block or a reset. Existing history loads as Focus. Older records retain their original focused duration and show estimated timing because pause intervals were not recorded.

Choose a break buddy and adjust its size (50–150%) in Settings, with a live preview. It also appears in the main timer during a break. The break timer and its companion join all macOS desktops and fullscreen Spaces. The companion stays within the current screen, never takes keyboard focus, and disappears when the break ends or is skipped. Character motion respects macOS Reduce Motion.

Run the history, allocation, and timer lifecycle checks with `./scripts/test.sh`. This also locates the Swift Testing framework in Command Line Tools installations.
