# TrainMenu

A macOS menu bar app that shows live (schedule-derived) upcoming departures for
Tokyo-area train lines you care about. Click the menu bar icon to see the next
trains for each board you've configured (line → station → direction).

Built with SwiftUI `MenuBarExtra` (macOS 13+). Works fully offline from a
bundled, compressed timetable snapshot.

> Status: **Phase 3 complete** — you can now add/remove/reorder your own boards
> in a settings window (line → station → direction), choose a display language,
> set how many departures to show, and toggle launch-at-login. Boards and
> preferences persist across launches. First launch shows an empty state until
> you add a board. Packaging (Phase 4) and the optional real-time delay overlay
> (Phase 5) remain — see Roadmap.

## Data

The app is driven by the Tokyo-area rail dataset in `data/` (ODPT /
Mini-Tokyo-3D format): 174 lines, 2,522 stations, plus directions, train types,
and per-line schedules. The schedules are **static timetables** — there are no
real-time delay fields. v1 derives a live countdown from the schedule + system
clock; actual delays are a later phase (see Roadmap).

`Scripts/build-data-snapshot.py` compresses `data/` into the bundle-ready
snapshot at `Sources/TrainMenu/Resources/Data/` (~7 MB). Each file is stored as
a raw-DEFLATE stream that Swift reads with `NSData.decompressed(using: .zlib)`.
The 127 MB of timetables become individually compressed per-line files that are
decompressed lazily, only for the lines you actually view.

## Build & run

```sh
# 1. Generate the compressed snapshot (required before first build, and
#    whenever data/ changes). Output is gitignored.
python3 Scripts/build-data-snapshot.py

# 2. Build
swift build

# 3a. Verify the data pipeline headlessly (no GUI needed)
swift run TrainMenu --selftest

# 3b. Launch the menu bar app (requires a desktop session)
swift run TrainMenu
```

You can also open `Package.swift` directly in Xcode.

## Project layout

```
Package.swift
Scripts/build-data-snapshot.py     # data/ -> compressed snapshot
data/                              # source dataset
Sources/TrainMenu/
  App/        Main, TrainMenuApp (MenuBarExtra), AppState, SelfTest
  Models/     Railway, Station, RailDirection, TrainType, TrainVehicle,
              TrainTimetable, TimetableStop
  Data/       ResourceLoader, DataStore (metadata), TimetableRepo (lazy lines),
              CalendarResolver, DepartureService
  Resources/Data/   generated snapshot (gitignored)
```

## Roadmap

- [x] **Phase 1** — scaffold, models, snapshot build step, metadata loader, self-test
- [ ] **Phase 2** — Japanese national-holiday calendar + service-day/after-midnight edge cases
- [x] **Phase 3** — Settings UI (line → station → direction), saved boards, persistence, launch-at-login
- [ ] **Phase 4** — Packaging: ad-hoc-signed `.app`, Gatekeeper-bypass docs, GitHub Release (no paid Apple account)
- [ ] **Phase 5** — Optional ODPT real-time delay overlay (free token). `Departure.delayMinutes` is already plumbed through.

## Settings

Click the menu bar tram icon → **Settings…**. There you can:

- **Add a board** — pick a line (searchable), then a station and a direction.
- **Reorder** boards by dragging; **remove** with the trash button (or swipe).
- **Language** — switches the entire UI (menu + settings labels *and* line/station
  titles) between English, 日本語, 한국어, Français, 简体中文, and 繁體中文. UI strings
  follow this in-app setting, not the system locale (see `Localization.swift`).
- **Departures per board** — 1–8.
- **Launch at login** — registers via `SMAppService` (works once the app is a
  signed bundle; an unbundled dev build may report an error here).
