import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    // New-board form: typed text + the resolved selection (set only when a
    // suggestion is picked).
    @State private var lineQuery = ""
    @State private var stationQuery = ""
    @State private var newRailwayId: String?
    @State private var newStationId: String?
    @State private var newDirectionId: String?

    var body: some View {
        List {
            boardsSection
            addSection
            prefsSection
        }
        .listStyle(.inset)
        .frame(minWidth: 460, minHeight: 560)
    }

    private func sectionHeader(_ key: L10n.Key) -> some View {
        Text(L10n.t(key, state.language))
            .font(.title3.weight(.bold))
            .textCase(nil)
            .foregroundStyle(.primary)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    // MARK: Saved boards

    private var boardsSection: some View {
        Section {
            if state.boards.isEmpty {
                Text(L10n.t(.addOneBelow, state.language)).foregroundStyle(.secondary)
            } else {
                ForEach(state.boards) { board in
                    BoardConfigRow(board: board)
                }
                .onMove { state.moveBoards(from: $0, to: $1) }
                .onDelete { state.removeBoards(at: $0) }
            }
        } header: {
            sectionHeader(.yourBoards)
        }
    }

    // MARK: Add a board (typeahead)

    private var addSection: some View {
        Section {
            // Line input
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.t(.line, state.language)).frame(width: 70, alignment: .leading)
                    TextField(L10n.t(.searchLines, state.language), text: $lineQuery)
                        .textFieldStyle(.roundedBorder)
                }
                if !lineMatches.isEmpty {
                    SuggestionBox {
                        ForEach(lineMatches) { lineSuggestion($0) }
                    }
                }
            }
            .onChange(of: lineQuery) { newValue in
                // Invalidate the resolved line if the text no longer matches it.
                if let rid = newRailwayId,
                   state.store?.railwayTitle(rid, language: state.language) != newValue {
                    newRailwayId = nil
                    newStationId = nil
                    stationQuery = ""
                    newDirectionId = nil
                }
            }

            // Station input
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L10n.t(.station, state.language)).frame(width: 70, alignment: .leading)
                    TextField(L10n.t(.searchStations, state.language), text: $stationQuery)
                        .textFieldStyle(.roundedBorder)
                        .disabled(newRailwayId == nil)
                }
                if !stationMatches.isEmpty {
                    SuggestionBox {
                        ForEach(stationMatches) { stationSuggestion($0) }
                    }
                }
            }
            .onChange(of: stationQuery) { newValue in
                if let sid = newStationId,
                   state.store?.stationTitle(sid, language: state.language) != newValue {
                    newStationId = nil
                }
            }

            // Direction (only two options — a picker is fine)
            Picker(L10n.t(.direction, state.language), selection: stringBinding($newDirectionId)) {
                ForEach(state.directions(forRailway: newRailwayId ?? "")) { d in
                    Text(state.store?.directionTitle(d.id, language: state.language) ?? d.id).tag(d.id)
                }
            }
            .disabled(newRailwayId == nil)

            Button(L10n.t(.addBoardButton, state.language)) {
                if let r = newRailwayId, let s = newStationId, let d = newDirectionId {
                    state.addBoard(railwayId: r, stationId: s, directionId: d)
                    resetForm()
                }
            }
            .disabled(newRailwayId == nil || newStationId == nil || newDirectionId == nil)
        } header: {
            sectionHeader(.addBoardSection)
        }
    }

    // MARK: Preferences

    private var prefsSection: some View {
        Section {
            Picker(L10n.t(.language, state.language), selection: $state.language) {
                ForEach(AppState.languages, id: \.self) { Text(languageName($0)).tag($0) }
            }
            Stepper(L10n.departuresPerBoard(state.departuresPerBoard, state.language),
                    value: $state.departuresPerBoard, in: 1...8)
            Toggle(L10n.t(.launchAtLogin, state.language), isOn: $state.launchAtLogin)
            if let err = state.loginItemError {
                Text(err).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            sectionHeader(.preferences)
        }
    }

    // MARK: Suggestions

    /// Up to 8 lines matching the typed text (empty once a line is resolved).
    private var lineMatches: [Railway] {
        let q = lineQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        if let rid = newRailwayId,
           state.store?.railwayTitle(rid, language: state.language) == q { return [] }
        return Array(state.railwaysSorted.filter {
            $0.title.localized(state.language).localizedCaseInsensitiveContains(q)
                || $0.id.localizedCaseInsensitiveContains(q)
        }.prefix(8))
    }

    /// Up to 10 stations on the chosen line matching the typed text.
    private var stationMatches: [Station] {
        guard let rid = newRailwayId else { return [] }
        let q = stationQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        if let sid = newStationId,
           state.store?.stationTitle(sid, language: state.language) == q { return [] }
        return Array(state.stations(forRailway: rid).filter {
            (state.store?.stationTitle($0.id, language: state.language) ?? $0.id)
                .localizedCaseInsensitiveContains(q)
                || $0.id.localizedCaseInsensitiveContains(q)
        }.prefix(10))
    }

    private func lineSuggestion(_ r: Railway) -> some View {
        Button {
            newRailwayId = r.id
            lineQuery = r.title.localized(state.language)
            newStationId = nil
            stationQuery = ""
            newDirectionId = state.directions(forRailway: r.id).first?.id
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: r.color) ?? .gray).frame(width: 9, height: 9)
                Text(r.title.localized(state.language))
                Spacer()
                Text(operatorName(r.id)).font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
    }

    private func stationSuggestion(_ s: Station) -> some View {
        Button {
            newStationId = s.id
            stationQuery = state.store?.stationTitle(s.id, language: state.language) ?? s.id
        } label: {
            Text(state.store?.stationTitle(s.id, language: state.language) ?? s.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
    }

    private func resetForm() {
        lineQuery = ""
        stationQuery = ""
        newRailwayId = nil
        newStationId = nil
        newDirectionId = nil
    }

    /// A non-optional String binding backed by an optional, for Picker selection.
    private func stringBinding(_ source: Binding<String?>) -> Binding<String> {
        Binding(get: { source.wrappedValue ?? "" }, set: { source.wrappedValue = $0 })
    }
}

/// A bordered container that visually groups suggestion rows under an input.
private struct SuggestionBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(4)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct BoardConfigRow: View {
    @EnvironmentObject var state: AppState
    let board: BoardConfig

    var body: some View {
        let store = state.store
        HStack(spacing: 8) {
            Circle().fill(Color(hex: store?.railwaysById[board.railwayId]?.color) ?? .gray)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(store?.railwayTitle(board.railwayId, language: state.language) ?? board.railwayId)
                Text("\(store?.stationTitle(board.stationId, language: state.language) ?? board.stationId) → \(store?.directionTitle(board.directionId, language: state.language) ?? board.directionId)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                state.boards.removeAll { $0.id == board.id }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(L10n.t(.removeBoard, state.language))
        }
    }
}

private func operatorName(_ railwayId: String) -> String {
    String(railwayId.split(separator: ".").first ?? "")
}

private func languageName(_ code: String) -> String {
    switch code {
    case "en": return "English"
    case "ja": return "日本語"
    case "ko": return "한국어"
    case "fr": return "Français"
    case "zh-Hans": return "简体中文"
    case "zh-Hant": return "繁體中文"
    default: return code
    }
}
