# Pomo

A minimalist, native Pomodoro timer for macOS. Pomo keeps its data local and helps you leave a small trail of checkpoints while you work.

## Run

Pomo requires macOS 14 or later and the Apple Command Line Tools. Build a normal macOS app bundle with:

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
- Breaks start automatically; finishing or skipping one returns to a stopped next-focus timer
- Completion notifications and sound
- Persistent menu bar countdown that automatically opens its break window at every focus boundary

Session history and settings are stored in macOS `UserDefaults` for the current user. No account, network connection, or analytics are used.
