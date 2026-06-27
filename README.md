# TrainMenu

A macOS menu bar app that shows live (schedule-derived) upcoming departures for
Tokyo-area train lines you care about. Click the menu bar icon to see the next
trains for each board you've configured (line → station → direction).

Built with SwiftUI `MenuBarExtra` (macOS 13+). Works fully offline from a
bundled, compressed timetable snapshot.

> Status: **Phases 1, 3, 4, 5 done.** Add/remove/reorder your own boards in a
> settings window (line → station → direction), pick a display language, set how
> many departures to show, toggle launch-at-login, and — with your own free ODPT
> key — see live line status. Boards and preferences persist. Build a downloadable
> universal `.app` with `Scripts/build-app.sh`. Only the holiday-calendar
> correctness pass (Phase 2) remains — see Roadmap.

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
- [x] **Phase 4** — Packaging: universal signed `.app` + `.zip`, Gatekeeper-bypass docs (no paid Apple account)
- [x] **Phase 5** — ODPT real-time delay overlay (per-user free key). Live `odpt:Train` delays matched to scheduled departures by train number.

## Packaging & install

Build a downloadable, code-signed app (no paid Apple account needed):

```sh
Scripts/build-app.sh     # → dist/TrainMenu.app and dist/TrainMenu.zip (~7 MB, universal)
```

The result is a menu-bar-only app (`LSUIElement`, universal arm64 + x86_64),
ad-hoc signed by default.

**Stable signature (optional, recommended):** ad-hoc signatures change every
build, so macOS re-prompts for Keychain access each time. Create a one-time
self-signed code-signing identity so "Always Allow" sticks:

```sh
Scripts/make-signing-cert.sh
export CODESIGN_IDENTITY="TrainMenu Self-Signed"
Scripts/build-app.sh
```

**Installing (the app is signed but not notarized — no $99 account):** downloaders
clear quarantine once:

```sh
xattr -dr com.apple.quarantine /Applications/TrainMenu.app
```

or right-click → **Open**, or System Settings → Privacy & Security → **Open Anyway**.

## Real-time (ODPT)

Two real-time layers, by what the key can access:

- **Line status — `odpt:TrainInformation`** (works with a standard ODPT Center
  key, covers JR-East, Metro, Toei, private lines). Each board shows its line's
  live status: a green dot + 平常運行 (normal) or an orange dot + the disruption
  text. One request per poll covers every board.
- **Per-train delays — `odpt:Train`** (challenge-tier access only). When the key
  can see it, each departure also gets a red `+Nm` badge and an adjusted
  countdown. With a plain Center key this layer is simply empty — that's expected,
  not a bug. Real-time train *location/delay* on ODPT is gated to the annual Open
  Data Challenge (`api-challenge.odpt.org`), which needs a separate challenge key.

**Each user supplies their own free key** — keys are per-developer and
rate-limited, so the app never bundles one. With no key the app is schedule-only;
add a key in **Settings → Real-time** (stored in the macOS Keychain). Get a free
key at [developer.odpt.org](https://developer.odpt.org).

Verify a key from the CLI without the GUI (prints both layers):
```sh
ODPT_API_KEY=yourkey swift run TrainMenu --rt-probe JR-East.Yamanote
```

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
