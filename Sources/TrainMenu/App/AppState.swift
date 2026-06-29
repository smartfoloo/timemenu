import AppKit
import Foundation
import ServiceManagement
import SwiftUI

/// Central app model: owns the offline data, the user's saved boards and
/// preferences (persisted to UserDefaults), and the live computed departures.
@MainActor
final class AppState: ObservableObject {
    // MARK: Data
    private(set) var store: DataStore?
    private var repo: TimetableRepo?
    private var service: DepartureService?
    @Published var loadError: String?

    // MARK: Persisted preferences
    @Published var boards: [BoardConfig] {
        didSet { persistBoards(); refreshAll(); refreshRealtime() }
    }
    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }  // views re-resolve titles
    }
    @Published var departuresPerBoard: Int {
        didSet { defaults.set(departuresPerBoard, forKey: Keys.perBoard); refreshAll() }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard !suppressLoginSync, launchAtLogin != oldValue else { return }
            syncLoginItem(revertingTo: oldValue)
        }
    }
    @Published var loginItemError: String?

    // MARK: Real-time (ODPT)
    /// The user's own ODPT consumer key (Keychain-backed). Empty = schedule-only.
    @Published var apiKey: String {
        didSet {
            guard apiKey != oldValue else { return }
            Keychain.set(apiKey)
            refreshRealtime()
        }
    }
    @Published var realtimeError: String?
    @Published var realtimeUpdatedAt: Date?
    var realtimeEnabled: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    // MARK: Live data
    @Published var boardDepartures: [UUID: [Departure]] = [:]
    /// railwayId -> live line status (odpt:TrainInformation).
    @Published var statusByRailway: [String: LineStatus] = [:]

    /// railwayId -> (trainNumber -> delay seconds), from the last ODPT poll.
    private var delaysByRailway: [String: [String: Int]] = [:]

    static let languages = ["en", "ja", "ko", "fr", "zh-Hans", "zh-Hant"]

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private var realtimeTimer: Timer?
    private var suppressLoginSync = false
    private var settingsWindow: NSWindow?
    private let settingsWindowDelegate = SettingsWindowDelegate()

    private enum Keys {
        static let boards = "boards"
        static let language = "language"
        static let perBoard = "departuresPerBoard"
    }

    init() {
        // Load persisted prefs first (property observers don't fire during init).
        boards = Self.decodeBoards(defaults.data(forKey: Keys.boards))
        language = defaults.string(forKey: Keys.language) ?? "en"
        let n = defaults.integer(forKey: Keys.perBoard)
        departuresPerBoard = (1...8).contains(n) ? n : 4
        launchAtLogin = SMAppService.mainApp.status == .enabled
        apiKey = Keychain.get() ?? ""

        do {
            let store = try DataStore()
            let repo = TimetableRepo(store: store)
            self.store = store
            self.repo = repo
            self.service = DepartureService(store: store, repo: repo)
        } catch {
            loadError = String(describing: error)
        }

        refreshAll()
        refreshRealtime()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAll() }
        }
        // ODPT updates roughly once a minute; poll on its own cadence.
        realtimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshRealtime() }
        }

        // Debug hook: launch, auto-open Settings, report state, quit.
        if CommandLine.arguments.contains("--open-settings") {
            FileHandle.standardError.write(Data("POLICY_AT_LAUNCH=\(NSApp.activationPolicy().rawValue)\n".utf8))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.openSettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    let win = self?.settingsWindow
                    let lines = [
                        "SETTINGS_WINDOW_VISIBLE=\(win?.isVisible ?? false)",
                        "POLICY_AFTER_OPEN=\(NSApp.activationPolicy().rawValue)",  // 0=regular 1=accessory
                        "IS_KEY_WINDOW=\(win?.isKeyWindow ?? false)",             // must be true to type
                        "APP_ACTIVE=\(NSApp.isActive)",
                    ]
                    FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
                    NSApp.terminate(nil)
                }
            }
        }
    }

    // MARK: - Departures

    func refreshAll() {
        guard let service else { return }
        var result: [UUID: [Departure]] = [:]
        for board in boards {
            result[board.id] = (try? service.upcoming(
                railwayId: board.railwayId,
                stationId: board.stationId,
                directionId: board.directionId,
                limit: departuresPerBoard,
                delaysByTrainNumber: delaysByRailway[board.railwayId] ?? [:]
            )) ?? []
        }
        boardDepartures = result
    }

    // MARK: - Real-time

    /// Poll ODPT for live line status (and, if the key has access, per-train
    /// delays) on the railways currently shown, then re-apply.
    func refreshRealtime() {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            delaysByRailway = [:]
            statusByRailway = [:]
            realtimeError = nil
            realtimeUpdatedAt = nil
            refreshAll()
            return
        }
        let railways = Set(boards.map(\.railwayId))
        guard !railways.isEmpty else { return }
        let client = ODPTClient(consumerKey: key)

        Task { @MainActor in
            var status: [String: LineStatus] = [:]
            var delays: [String: [String: Int]] = [:]
            var primaryError: String?

            // 1) Line status — available to a standard ODPT Center key.
            do {
                for info in try await client.trainInformation() {
                    guard let raw = info.railway else { continue }
                    let rid = raw.replacingOccurrences(of: "odpt.Railway:", with: "")
                    guard railways.contains(rid) else { continue }
                    status[rid] = LineStatus(text: info.text ?? [:], statusLabel: info.status)
                }
            } catch {
                primaryError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }

            // 2) Per-train delays — only present for challenge-tier keys; best-effort.
            for railway in railways {
                if let trains = try? await client.trains(railwayId: railway) {
                    var map: [String: Int] = [:]
                    for t in trains where t.trainNumber != nil && t.delaySeconds != nil {
                        map[t.trainNumber!] = t.delaySeconds!
                    }
                    if !map.isEmpty { delays[railway] = map }
                }
            }

            self.statusByRailway = status
            self.delaysByRailway = delays
            self.realtimeError = primaryError
            self.realtimeUpdatedAt = primaryError == nil ? Date() : self.realtimeUpdatedAt
            self.refreshAll()
        }
    }

    // MARK: - Board editing

    func addBoard(railwayId: String, stationId: String, directionId: String) {
        boards.append(BoardConfig(railwayId: railwayId, stationId: stationId, directionId: directionId))
    }

    func removeBoards(at offsets: IndexSet) {
        boards.remove(atOffsets: offsets)
    }

    func moveBoards(from source: IndexSet, to destination: Int) {
        boards.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Lookups for the settings UI

    var railwaysSorted: [Railway] {
        (store?.railways ?? []).sorted {
            $0.title.localized(language).localizedCaseInsensitiveCompare($1.title.localized(language)) == .orderedAscending
        }
    }

    /// Stations along a line, in order, de-duplicated (loop lines repeat termini).
    func stations(forRailway id: String) -> [Station] {
        guard let railway = store?.railwaysById[id] else { return [] }
        var seen = Set<String>()
        return railway.stations.compactMap { sid in
            guard seen.insert(sid).inserted, let s = store?.stationsById[sid] else { return nil }
            return s
        }
    }

    func directions(forRailway id: String) -> [RailDirection] {
        guard let railway = store?.railwaysById[id] else { return [] }
        return [railway.ascending, railway.descending]
            .compactMap { $0 }
            .compactMap { store?.directionsById[$0] }
    }

    /// Directions valid for departures from `stationId` on the given line.
    ///
    /// At a line terminus only one direction has any trains: the first station
    /// runs only in the ascending-index (`ascending`) direction, the last only in
    /// the descending-index (`descending`) direction. Loop lines (where the termini
    /// coincide, or the directions are an inner/outer loop) keep both.
    func directions(forRailway id: String, station stationId: String?) -> [RailDirection] {
        guard let railway = store?.railwaysById[id] else { return [] }
        let all = directions(forRailway: id)
        guard let stationId,
              let first = railway.stations.first,
              let last = railway.stations.last,
              first != last
        else { return all }

        // Don't restrict loop lines, where both directions run at every station.
        let isLoop = [railway.ascending, railway.descending]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains("Loop") }
        if isLoop { return all }

        func resolve(_ directionId: String?) -> [RailDirection] {
            [directionId].compactMap { $0 }.compactMap { store?.directionsById[$0] }
        }

        if stationId == first { return resolve(railway.ascending) }
        if stationId == last { return resolve(railway.descending) }
        return all
    }

    /// Cache of destination station ids per (railway, station, direction). The
    /// underlying timetables are static, so entries never need invalidating.
    private var directionDestCache: [String: [String]] = [:]

    /// A descriptive direction label such as "横浜・元町・中華街方面", naming where
    /// the line (and its through-services) heads from this station. Falls back to
    /// the plain direction name (上り/下り) for loop lines or before a station is
    /// chosen.
    func directionLabel(railwayId: String, stationId: String, directionId: String) -> String {
        let key = "\(railwayId)|\(stationId)|\(directionId)"
        let ids: [String]
        if let cached = directionDestCache[key] {
            ids = cached
        } else {
            ids = service?.directionDestinations(
                railwayId: railwayId, stationId: stationId, directionId: directionId) ?? []
            directionDestCache[key] = ids
        }
        guard let store, !ids.isEmpty else {
            return store?.directionTitle(directionId, language: language) ?? directionId
        }
        return L10n.directionToward(ids.map { store.stationTitle($0, language: language) }, language)
    }

    // MARK: - Persistence

    private func persistBoards() {
        defaults.set(try? JSONEncoder().encode(boards), forKey: Keys.boards)
    }

    private static func decodeBoards(_ data: Data?) -> [BoardConfig] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([BoardConfig].self, from: data)) ?? []
    }

    // MARK: - Launch at login

    private func syncLoginItem(revertingTo oldValue: Bool) {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            // Common when running an unbundled dev build; works once packaged.
            loginItemError = error.localizedDescription
            suppressLoginSync = true
            launchAtLogin = oldValue
            suppressLoginSync = false
        }
    }

    // MARK: - Settings window

    func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView().environmentObject(self))
            let win = NSWindow(contentViewController: hosting)
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.setContentSize(NSSize(width: 480, height: 600))
            win.center()
            win.delegate = settingsWindowDelegate
            settingsWindow = win
        }
        // Defer to the next runloop tick: the MenuBarExtra popover is still
        // dismissing when this action fires, and showing the window inline races
        // with it.
        DispatchQueue.main.async { [weak self] in
            guard let self, let win = self.settingsWindow else { return }
            win.title = L10n.t(.settingsWindowTitle, self.language)
            // A MenuBarExtra-only app launches as `.prohibited`, so it can never
            // become the active app and its windows can't become key — meaning no
            // keyboard input. Become a regular app while Settings is open so text
            // fields accept typing; the delegate reverts to `.accessory` on close.
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            win.orderFrontRegardless()
        }
    }
}

/// Returns the app to a menu-bar-only (no Dock icon) agent when the Settings
/// window closes.
private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
