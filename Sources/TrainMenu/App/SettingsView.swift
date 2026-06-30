import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var showAddSheet = false

    private var lang: String { state.language }

    var body: some View {
        Form {
            boardsSection
            realtimeSection
            prefsSection
        }
        .formStyle(.grouped)
        .font(state.font(.body))   // default text size for all controls in the form
        .frame(minWidth: 460, minHeight: 520)
        .sheet(isPresented: $showAddSheet) {
            AddBoardSheet().environmentObject(state)
        }
    }

    private func sectionHeader(_ key: L10n.Key) -> some View {
        Text(L10n.t(key, lang))
            .font(state.font(.title2, weight: .bold))
            .textCase(nil)
            .foregroundStyle(.primary)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

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

            Button {
                showAddSheet = true
            } label: {
                Label(L10n.t(.addBoardButton, lang), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
        } header: {
            sectionHeader(.yourBoards)
        }
    }

    private var realtimeSection: some View {
        let ok = state.realtimeError == nil
        let iconName = state.realtimeEnabled
            ? (ok ? "dot.radiowaves.left.and.right" : "exclamationmark.triangle")
            : "clock"
        let iconColor: Color = state.realtimeEnabled ? (ok ? .green : .orange) : .gray
        let statusText = state.realtimeError
            ?? (state.realtimeEnabled ? L10n.t(.realtimeOn, lang) : L10n.t(.realtimeOff, lang))
        let statusColor: Color = ok ? Color(nsColor: .secondaryLabelColor) : .orange

        return Section {
            SecureField(L10n.t(.apiKeyLabel, lang), text: $state.apiKey,
                        prompt: Text(L10n.t(.apiKeyPrompt, lang)))

            HStack(spacing: 6) {
                Image(systemName: iconName).foregroundStyle(iconColor)
                Text(statusText).font(state.font(.caption)).foregroundStyle(statusColor)
            }

            Link(L10n.t(.getFreeKey, lang), destination: URL(string: "https://developer.odpt.org")!)
                .font(state.font(.caption))
        } header: {
            sectionHeader(.realtimeSection)
        }
    }

    private var prefsSection: some View {
        Section {
            Picker(L10n.t(.language, lang), selection: $state.language) {
                ForEach(AppState.languages, id: \.self) { Text(languageName($0)).tag($0) }
            }
            Stepper(L10n.departuresPerBoard(state.departuresPerBoard, lang),
                    value: $state.departuresPerBoard, in: 1...8)
            Picker(L10n.t(.textSize, lang), selection: $state.boardTextSize) {
                ForEach(BoardTextSize.allCases) { size in
                    Text(L10n.textSizeName(size, lang)).tag(size)
                }
            }
            Toggle(L10n.t(.launchAtLogin, lang), isOn: $state.launchAtLogin)
            if let err = state.loginItemError {
                Text(err).font(state.font(.caption)).foregroundStyle(.secondary)
            }
        } header: {
            sectionHeader(.preferences)
        }
    }
}

/// Modal sheet for composing a new board via type-ahead line/station inputs.
struct AddBoardSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var lineQuery = ""
    @State private var stationQuery = ""
    @State private var newRailwayId: String?
    @State private var newStationId: String?
    @State private var newDirectionId: String?

    private var lang: String { state.language }
    private var canAdd: Bool { newRailwayId != nil && newStationId != nil && newDirectionId != nil }

    /// Directions offered for the current line/station, narrowed to one at a terminus.
    private var availableDirections: [RailDirection] {
        state.directions(forRailway: newRailwayId ?? "", station: newStationId)
    }

    /// Descriptive label ("…方面") once a station is picked, else the plain name.
    private func directionLabel(_ d: RailDirection) -> String {
        guard let rid = newRailwayId, let sid = newStationId else {
            return state.store?.directionTitle(d.id, language: lang) ?? d.id
        }
        return state.directionLabel(railwayId: rid, stationId: sid, directionId: d.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.t(.addBoardSection, lang)).font(state.font(.title2, weight: .bold))
                Spacer()
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            Divider()

            Form {
                Section {
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

                    Picker(L10n.t(.direction, lang), selection: stringBinding($newDirectionId)) {
                        ForEach(availableDirections) { d in
                            Text(directionLabel(d)).tag(d.id)
                        }
                    }
                    .disabled(newRailwayId == nil || availableDirections.count <= 1)
                }
            }
            .formStyle(.grouped)
            .font(state.font(.body))

            Divider()

            HStack {
                Spacer()
                Button(L10n.t(.cancel, lang)) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L10n.t(.addBoardButton, lang)) {
                    if let r = newRailwayId, let s = newStationId, let d = newDirectionId {
                        state.addBoard(railwayId: r, stationId: s, directionId: d)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdd)
            }
            .padding()
        }
        .frame(width: 470, height: 500)
    }

    // MARK: Suggestions

    private var lineMatches: [Railway] {
        let q = lineQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        if let rid = newRailwayId, state.store?.railwayTitle(rid, language: lang) == q { return [] }
        return Array(state.railwaysSorted.filter {
            (state.store?.railwayTitle($0.id, language: lang) ?? $0.id).localizedCaseInsensitiveContains(q)
                || state.store?.operatorName($0.id, language: lang).localizedCaseInsensitiveContains(q) == true
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
            lineQuery = state.store?.railwayTitle(r.id, language: lang) ?? r.id
            newStationId = nil
            stationQuery = ""
            newDirectionId = state.directions(forRailway: r.id).first?.id
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: r.color) ?? .gray).frame(width: 9, height: 9)
                Text(state.store?.railwayTitle(r.id, language: lang) ?? r.id)
                Spacer()
                Text(state.store?.operatorName(r.id, language: lang) ?? "").font(state.font(.caption)).foregroundStyle(.secondary)
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
            // Snap the direction to the only valid one at a terminus, or keep the
            // current choice if it's still offered for this station.
            let directions = state.directions(forRailway: newRailwayId ?? "", station: s.id)
            if !directions.contains(where: { $0.id == newDirectionId }) {
                newDirectionId = directions.first?.id
            }
        } label: {
            Text(state.store?.stationTitle(s.id, language: lang) ?? s.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.vertical, 5).padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

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
                Text("\(store?.stationTitle(board.stationId, language: state.language) ?? board.stationId) → \(state.directionLabel(railwayId: board.railwayId, stationId: board.stationId, directionId: board.directionId))")
                    .font(state.font(.caption)).foregroundStyle(.secondary)
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
