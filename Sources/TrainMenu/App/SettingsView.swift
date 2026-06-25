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

    private var lang: String { state.language }

    var body: some View {
        Form {
            boardsSection
            addSection
            prefsSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 560)
    }

    private func sectionHeader(_ key: L10n.Key) -> some View {
        Text(L10n.t(key, lang))
            .font(.title2.weight(.bold))
            .textCase(nil)
            .foregroundStyle(.primary)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    // MARK: Saved boards

    private var boardsSection: some View {
        Section {
            if state.boards.isEmpty {
                Text(L10n.t(.addOneBelow, lang)).foregroundStyle(.secondary)
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
            // Line — title becomes the aligned leading label in a grouped Form.
            TextField(L10n.t(.line, lang), text: $lineQuery, prompt: Text(L10n.t(.searchLines, lang)))
                .onChange(of: lineQuery) { newValue in
                    if let rid = newRailwayId,
                       state.store?.railwayTitle(rid, language: lang) != newValue {
                        newRailwayId = nil
                        newStationId = nil
                        stationQuery = ""
                        newDirectionId = nil
                    }
                }
            if !lineMatches.isEmpty {
                suggestionList(lineMatches) { lineSuggestion($0) }
            }

            // Station
            TextField(L10n.t(.station, lang), text: $stationQuery, prompt: Text(L10n.t(.searchStations, lang)))
                .disabled(newRailwayId == nil)
                .onChange(of: stationQuery) { newValue in
                    if let sid = newStationId,
                       state.store?.stationTitle(sid, language: lang) != newValue {
                        newStationId = nil
                    }
                }
            if !stationMatches.isEmpty {
                suggestionList(stationMatches) { stationSuggestion($0) }
            }

            // Direction (two options — a picker is the right control here)
            Picker(L10n.t(.direction, lang), selection: stringBinding($newDirectionId)) {
                ForEach(state.directions(forRailway: newRailwayId ?? "")) { d in
                    Text(state.store?.directionTitle(d.id, language: lang) ?? d.id).tag(d.id)
                }
            }
            .disabled(newRailwayId == nil)

            HStack {
                Spacer()
                Button(L10n.t(.addBoardButton, lang)) {
                    if let r = newRailwayId, let s = newStationId, let d = newDirectionId {
                        state.addBoard(railwayId: r, stationId: s, directionId: d)
                        resetForm()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newRailwayId == nil || newStationId == nil || newDirectionId == nil)
            }
        } header: {
            sectionHeader(.addBoardSection)
        }
    }

    // MARK: Preferences

    private var prefsSection: some View {
        Section {
            Picker(L10n.t(.language, lang), selection: $state.language) {
                ForEach(AppState.languages, id: \.self) { Text(languageName($0)).tag($0) }
            }
            Stepper(L10n.departuresPerBoard(state.departuresPerBoard, lang),
                    value: $state.departuresPerBoard, in: 1...8)
            Toggle(L10n.t(.launchAtLogin, lang), isOn: $state.launchAtLogin)
            if let err = state.loginItemError {
                Text(err).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            sectionHeader(.preferences)
        }
    }

    // MARK: Suggestions

    private var lineMatches: [Railway] {
        let q = lineQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        if let rid = newRailwayId, state.store?.railwayTitle(rid, language: lang) == q { return [] }
        return Array(state.railwaysSorted.filter {
            $0.title.localized(lang).localizedCaseInsensitiveContains(q)
                || $0.id.localizedCaseInsensitiveContains(q)
        }.prefix(8))
    }

    private var stationMatches: [Station] {
        guard let rid = newRailwayId else { return [] }
        let q = stationQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        if let sid = newStationId, state.store?.stationTitle(sid, language: lang) == q { return [] }
        return Array(state.stations(forRailway: rid).filter {
            (state.store?.stationTitle($0.id, language: lang) ?? $0.id).localizedCaseInsensitiveContains(q)
                || $0.id.localizedCaseInsensitiveContains(q)
        }.prefix(10))
    }

    /// A bordered, full-width list of tappable suggestion rows under an input.
    private func suggestionList<T: Identifiable, Row: View>(
        _ items: [T], @ViewBuilder row: @escaping (T) -> Row
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                row(item)
            }
        }
        .padding(.vertical, 2)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 4, trailing: 12))
    }

    private func lineSuggestion(_ r: Railway) -> some View {
        Button {
            newRailwayId = r.id
            lineQuery = r.title.localized(lang)
            newStationId = nil
            stationQuery = ""
            newDirectionId = state.directions(forRailway: r.id).first?.id
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: r.color) ?? .gray).frame(width: 9, height: 9)
                Text(r.title.localized(lang))
                Spacer()
                Text(operatorName(r.id)).font(.caption).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 5).padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private func stationSuggestion(_ s: Station) -> some View {
        Button {
            newStationId = s.id
            stationQuery = state.store?.stationTitle(s.id, language: lang) ?? s.id
        } label: {
            Text(state.store?.stationTitle(s.id, language: lang) ?? s.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.vertical, 5).padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
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

struct BoardConfigRow: View {
    @EnvironmentObject var state: AppState
    let board: BoardConfig

    var body: some View {
        let store = state.store
        HStack(spacing: 9) {
            Circle().fill(Color(hex: store?.railwaysById[board.railwayId]?.color) ?? .gray)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(store?.railwayTitle(board.railwayId, language: state.language) ?? board.railwayId)
                    .fontWeight(.medium)
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
        .padding(.vertical, 2)
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
