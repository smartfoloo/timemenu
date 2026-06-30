import SwiftUI

/// Menu bar app. `Main` calls `TimemenuApp.main()`; this type is intentionally
/// not annotated `@main`. MenuBarExtra is the only scene — the settings window is
/// managed manually (see `AppState.openSettings`) so nothing auto-opens at launch.
struct TimemenuApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra("Timemenu", systemImage: "tram.fill") {
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
                Text("Timemenu").font(state.font(.title2, weight: .semibold))
                Spacer()
            }

            if let err = state.loadError {
                Text(err).font(state.font(.callout)).foregroundStyle(.red).textSelection(.enabled)
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
            Text(L10n.t(.noBoardsTitle, state.language)).font(state.font(.body))
            Text(L10n.t(.emptyStateBody, state.language))
                .font(state.font(.subheadline)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack {
            Button(L10n.t(.settings, state.language)) { state.openSettings() }
                .font(state.font(.body))
            Spacer()
            Button(L10n.t(.quit, state.language)) { NSApplication.shared.terminate(nil) }
                .font(state.font(.body))
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
        let dir = state.directionLabel(railwayId: board.railwayId, stationId: board.stationId, directionId: board.directionId)
        let result = state.boardDepartures[board.id] ?? .none
        let deps = result.departures

        return VStack(alignment: .leading, spacing: 4) {
            // Station name is the headline (previously the line name's slot).
            Text(station).font(state.font(.title3, weight: .semibold)).padding(.bottom, 2)
            // Line name carries the line color, sized like a departure row;
            // the live status sits compactly to its right (🟢 normal / ⚠️ disrupted).
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: store?.railwaysById[board.railwayId]?.color) ?? .gray)
                    .frame(width: 9 * state.boardTextSize.scale, height: 9 * state.boardTextSize.scale)
                Text(line).font(state.font(.body)).foregroundStyle(.secondary)
                if let status = state.statusByRailway[board.railwayId] {
                    let label = status.isNormal
                        ? L10n.t(.normalService, state.language)
                        : (status.statusLabel?.localized(state.language) ?? status.display(state.language))
                    // Push the status to the row's trailing edge.
                    Spacer(minLength: 8)
                    // Normal uses a green dot matching the line-color dot's size and
                    // spacing; disruptions keep the ⚠️ emoji.
                    if status.isNormal {
                        Circle()
                            .fill(.green)
                            .frame(width: 9 * state.boardTextSize.scale, height: 9 * state.boardTextSize.scale)
                    } else {
                        Text("⚠️").font(state.font(.body))
                    }
                    Text(label)
                        .font(state.font(.body))
                        .foregroundStyle(status.isNormal ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                        .lineLimit(1)
                }
            }
            // Direction sits where "station → dir" used to.
            Text(dir).font(state.font(.body)).foregroundStyle(.secondary)

            if deps.isEmpty {
                Text(L10n.t(result.serviceEnded ? .serviceEnded : .noUpcoming, state.language)).font(state.font(.subheadline)).foregroundStyle(.secondary).padding(.top, 1)
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
                .font(state.font(.subheadline, monospaced: true))
                .frame(width: 48 * state.boardTextSize.scale, alignment: .leading)
            Text(mins == 0 ? L10n.t(.now, state.language) : L10n.inMinutes(mins, state.language))
                .font(state.font(.body, weight: .medium))
                .foregroundStyle(mins <= 2 ? Color.orange : .secondary)
                .frame(width: 58 * state.boardTextSize.scale, alignment: .leading)
            HStack(spacing: 6) {
                if !type.isEmpty {
                    Text(type).font(state.font(.body, weight: .bold))   // 種別 (bold)
                }
                if !name.isEmpty {
                    Text(name).font(state.font(.body))
                }
                if !dest.isEmpty {
                    Text(dest).font(state.font(.body))                  // 行き先 (to the right of 種別)
                }
            }
            .lineLimit(1)
            if let delay = dep.delayMinutes, delay > 0 {
                Text("+\(delay)m").font(state.font(.callout, weight: .bold)).foregroundStyle(.red)
            }
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
