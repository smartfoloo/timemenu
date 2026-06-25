import SwiftUI

/// Menu bar app. `Main` calls `TrainMenuApp.main()`; this type is intentionally
/// not annotated `@main`. MenuBarExtra is the only scene — the settings window is
/// managed manually (see `AppState.openSettings`) so nothing auto-opens at launch.
struct TrainMenuApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("TrainMenu", systemImage: "tram.fill") {
            MenuContentView()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TrainMenu").font(.title2.weight(.semibold))
                Spacer()
            }

            if let err = state.loadError {
                Text(err).font(.callout).foregroundStyle(.red).textSelection(.enabled)
            } else if state.boards.isEmpty {
                emptyState
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(state.boards) { board in
                            BoardView(board: board, now: context.date)
                        }
                    }
                }
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 380)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t(.noBoardsTitle, state.language)).font(.body)
            Text(L10n.t(.emptyStateBody, state.language))
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            Button(L10n.t(.settings, state.language)) { state.openSettings() }
                .font(.body)
            Spacer()
            Button(L10n.t(.quit, state.language)) { NSApplication.shared.terminate(nil) }
                .font(.body)
        }
    }
}

/// One saved board's header + upcoming departures.
struct BoardView: View {
    @EnvironmentObject var state: AppState
    let board: BoardConfig
    let now: Date

    var body: some View {
        let store = state.store
        let line = store?.railwayTitle(board.railwayId, language: state.language) ?? board.railwayId
        let station = store?.stationTitle(board.stationId, language: state.language) ?? board.stationId
        let dir = store?.directionTitle(board.directionId, language: state.language) ?? board.directionId
        let deps = state.boardDepartures[board.id] ?? []

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color(hex: store?.railwaysById[board.railwayId]?.color) ?? .gray)
                    .frame(width: 11, height: 11)
                Text(line).font(.title3.weight(.semibold))
            }
            Text("\(station) → \(dir)").font(.subheadline).foregroundStyle(.secondary)

            if deps.isEmpty {
                Text(L10n.t(.noUpcoming, state.language)).font(.subheadline).foregroundStyle(.secondary).padding(.top, 1)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(deps) { dep in
                        DepartureRow(dep: dep, now: now)
                    }
                }
                .padding(.top, 1)
            }
        }
    }
}

struct DepartureRow: View {
    @EnvironmentObject var state: AppState
    let dep: Departure
    let now: Date

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = CalendarResolver.tokyo.timeZone
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        let store = state.store
        let mins = max(0, Int(dep.expected.timeIntervalSince(now) / 60))
        let type = store?.trainTypeTitle(dep.trainTypeId, language: state.language) ?? ""
        let name = dep.trainName?.localized(state.language) ?? ""
        let dest = dep.destinationIds
            .map { store?.stationTitle($0, language: state.language) ?? $0 }
            .joined(separator: "/")

        return HStack(spacing: 8) {
            // Time keeps its smaller, monospaced size; everything else is larger.
            Text(Self.timeFmt.string(from: dep.scheduled))
                .font(.system(.subheadline, design: .monospaced))
                .frame(width: 48, alignment: .leading)
            Text(mins == 0 ? L10n.t(.now, state.language) : L10n.inMinutes(mins, state.language))
                .font(.body.weight(.medium))
                .foregroundStyle(mins <= 2 ? Color.orange : .secondary)
                .frame(width: 58, alignment: .leading)
            HStack(spacing: 6) {
                if !type.isEmpty {
                    Text(type).font(.body.weight(.bold))   // 種別 (bold)
                }
                if !name.isEmpty {
                    Text(name).font(.body)
                }
                if !dest.isEmpty {
                    Text(dest).font(.body)                 // 行き先 (to the right of 種別)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

extension Color {
    /// Build a Color from a "#RRGGBB" hex string; nil if absent/unparseable.
    init?(hex: String?) {
        guard var s = hex else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}
