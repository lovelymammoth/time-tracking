# Time Tracker

A simple macOS menu bar app for tracking time per client and project — stopwatch or manual entry, with per-client Excel (.xlsx) and PDF export.

Built with SwiftUI (`MenuBarExtra`), no third-party dependencies. Runs entirely in the background with no Dock icon.

## Features

- Menu bar stopwatch: pick a client/project, start/stop a live timer
- Manual time entry (date, hours/minutes, notes)
- Edit or delete any logged entry after the fact
- Manage clients and their projects
- Time Log tab: filter by client and date range, see totals
- Export a client's time log as native `.xlsx` or PDF
- Data stored locally at `~/Library/Application Support/TimeTracker/data.json`

## Requirements

- macOS 13 (Ventura) or later
- Xcode Command Line Tools / Swift 5.9+ toolchain (only needed to build from source)

## Download

Grab the latest built app from the [Releases](../../releases) page, unzip, and drag `Time Tracker.app` into `/Applications`.

Since the app is signed ad-hoc (not notarized by Apple), the first time you open it macOS Gatekeeper will refuse to launch it normally. To open it:

1. Right-click (or Control-click) `Time Tracker.app` → **Open** → **Open** again in the dialog, **or**
2. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to the Time Tracker warning.

You only need to do this once.

## Building from source

```bash
git clone https://github.com/lovelymammoth/time-tracking.git
cd time-tracking
./build.sh
```

This runs `swift build -c release`, assembles `dist/Time Tracker.app` (with icon and `Info.plist`), and ad-hoc code-signs it.

Install it by copying to `/Applications`:

```bash
cp -R "dist/Time Tracker.app" /Applications/
open "/Applications/Time Tracker.app"
```

### Running without packaging

For quick iteration during development you can also just run:

```bash
swift build
.build/debug/TimeTracker
```

## Launch at login (optional)

System Settings → General → Login Items → add `Time Tracker.app`.

## Project layout

```
Sources/TimeTracker/
  Models/         Client, Project, TimeEntry
  Store/          DataStore (persistence + stopwatch state), AppNavigation
  Views/          Menu bar UI, Clients & Projects tab, Time Log tab, entry edit sheet
  Export/         Native XLSX (hand-written OOXML, zipped) and PDF (Core Graphics) exporters
  TimeTrackerApp.swift  App entry point (MenuBarExtra + main window)
Resources/AppIcon.icns
build.sh          Release build + .app packaging + codesign
```

## License

Personal project — no license specified.
