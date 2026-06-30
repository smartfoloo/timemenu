import Foundation

/// In-app UI string catalog. Strings follow the user's chosen display language
/// (the same `AppState.language` that localizes line/station titles), not the
/// system locale. Falls back to English, then the key name.
enum L10n {
    enum Key: String {
        case noBoardsTitle
        case emptyStateBody
        case settings
        case quit
        case noUpcoming
        case serviceEnded
        case now
        case yourBoards
        case addOneBelow
        case addBoardSection
        case line
        case choose
        case station
        case direction
        case addBoardButton
        case preferences
        case language
        case textSize
        case textSizeSmall
        case textSizeNormal
        case textSizeLarge
        case textSizeExtraLarge
        case launchAtLogin
        case chooseLine
        case noLinesForStation
        case done
        case searchLines
        case searchStations
        case removeBoard
        case cancel
        case realtimeSection
        case apiKeyLabel
        case apiKeyPrompt
        case getFreeKey
        case realtimeOff
        case realtimeOn
        case settingsWindowTitle
        case normalService
    }

    static func t(_ key: Key, _ lang: String) -> String {
        let row = table[key] ?? [:]
        return row[lang] ?? row["en"] ?? key.rawValue
    }

    /// Countdown such as "in 4m" / "4分後".
    static func inMinutes(_ m: Int, _ lang: String) -> String {
        switch lang {
        case "ja": return "\(m)分後"
        case "ko": return "\(m)분 후"
        case "fr": return "dans \(m) min"
        case "zh-Hans": return "\(m)分钟后"
        case "zh-Hant": return "\(m)分鐘後"
        default: return "in \(m)m"
        }
    }

    /// A descriptive direction heading from destination names, e.g.
    /// "横浜・元町・中華街方面" / "for Yokohama / Motomachi-Chukagai".
    static func directionToward(_ names: [String], _ lang: String) -> String {
        guard !names.isEmpty else { return "" }
        switch lang {
        case "ja", "zh-Hans", "zh-Hant":
            return names.joined(separator: "・") + "方面"
        case "ko":
            return names.joined(separator: "·") + " 방면"
        case "fr":
            return "direction " + names.joined(separator: " / ")
        default:
            return "for " + names.joined(separator: " / ")
        }
    }

    /// Localized name for a board text-size level (for the Settings picker).
    static func textSizeName(_ size: BoardTextSize, _ lang: String) -> String {
        switch size {
        case .small:      return t(.textSizeSmall, lang)
        case .normal:     return t(.textSizeNormal, lang)
        case .large:      return t(.textSizeLarge, lang)
        case .extraLarge: return t(.textSizeExtraLarge, lang)
        }
    }

    static func departuresPerBoard(_ n: Int, _ lang: String) -> String {
        switch lang {
        case "ja": return "ボードごとの本数: \(n)"
        case "ko": return "보드당 표시 수: \(n)"
        case "fr": return "Départs par tableau : \(n)"
        case "zh-Hans": return "每个看板班次数: \(n)"
        case "zh-Hant": return "每個看板班次數: \(n)"
        default: return "Departures per board: \(n)"
        }
    }

    private static let table: [Key: [String: String]] = [
        .noBoardsTitle: [
            "en": "No boards yet.",
            "ja": "ボードがありません",
            "ko": "보드가 없습니다",
            "fr": "Aucun tableau",
            "zh-Hans": "暂无看板",
            "zh-Hant": "尚無看板",
        ],
        .emptyStateBody: [
            "en": "Add a line, station, and direction in Settings to see upcoming trains here.",
            "ja": "設定で路線・駅・方向を追加すると、ここに発車予定が表示されます。",
            "ko": "설정에서 노선, 역, 방향을 추가하면 여기에 출발 예정이 표시됩니다.",
            "fr": "Ajoutez une ligne, une gare et une direction dans les Réglages pour voir les prochains trains ici.",
            "zh-Hans": "在设置中添加线路、车站和方向，即可在此查看即将发车的列车。",
            "zh-Hant": "在設定中新增路線、車站與方向，即可在此查看即將發車的列車。",
        ],
        .settings: [
            "en": "Settings…",
            "ja": "設定…",
            "ko": "설정…",
            "fr": "Réglages…",
            "zh-Hans": "设置…",
            "zh-Hant": "設定…",
        ],
        .quit: [
            "en": "Quit",
            "ja": "終了",
            "ko": "종료",
            "fr": "Quitter",
            "zh-Hans": "退出",
            "zh-Hant": "結束",
        ],
        .noUpcoming: [
            "en": "No upcoming trains.",
            "ja": "発車予定はありません",
            "ko": "예정된 열차가 없습니다",
            "fr": "Aucun train à venir.",
            "zh-Hans": "暂无即将发车的列车。",
            "zh-Hant": "暫無即將發車的列車。",
        ],
        .serviceEnded: [
            "en": "Service has ended for today.",
            "ja": "本日の運転は終了しました",
            "ko": "오늘 운행이 종료되었습니다",
            "fr": "Le service est terminé pour aujourd'hui.",
            "zh-Hans": "今日运营已结束。",
            "zh-Hant": "今日營運已結束。",
        ],
        .now: [
            "en": "now",
            "ja": "まもなく",
            "ko": "곧",
            "fr": "maintenant",
            "zh-Hans": "即将",
            "zh-Hant": "即將",
        ],
        .yourBoards: [
            "en": "Your boards",
            "ja": "ボード",
            "ko": "내 보드",
            "fr": "Vos tableaux",
            "zh-Hans": "我的看板",
            "zh-Hant": "我的看板",
        ],
        .addOneBelow: [
            "en": "No boards yet — add one below.",
            "ja": "ボードがありません — 下で追加してください。",
            "ko": "보드가 없습니다 — 아래에서 추가하세요.",
            "fr": "Aucun tableau — ajoutez-en un ci-dessous.",
            "zh-Hans": "暂无看板 — 在下方添加。",
            "zh-Hant": "尚無看板 — 在下方新增。",
        ],
        .addBoardSection: [
            "en": "Add a board",
            "ja": "ボードを追加",
            "ko": "보드 추가",
            "fr": "Ajouter un tableau",
            "zh-Hans": "添加看板",
            "zh-Hant": "新增看板",
        ],
        .line: [
            "en": "Line",
            "ja": "路線",
            "ko": "노선",
            "fr": "Ligne",
            "zh-Hans": "线路",
            "zh-Hant": "路線",
        ],
        .choose: [
            "en": "Choose…",
            "ja": "選択…",
            "ko": "선택…",
            "fr": "Choisir…",
            "zh-Hans": "选择…",
            "zh-Hant": "選擇…",
        ],
        .station: [
            "en": "Station",
            "ja": "駅",
            "ko": "역",
            "fr": "Gare",
            "zh-Hans": "车站",
            "zh-Hant": "車站",
        ],
        .direction: [
            "en": "Direction",
            "ja": "方向",
            "ko": "방향",
            "fr": "Direction",
            "zh-Hans": "方向",
            "zh-Hant": "方向",
        ],
        .addBoardButton: [
            "en": "Add Board",
            "ja": "追加",
            "ko": "추가",
            "fr": "Ajouter",
            "zh-Hans": "添加",
            "zh-Hant": "新增",
        ],
        .preferences: [
            "en": "Preferences",
            "ja": "環境設定",
            "ko": "환경설정",
            "fr": "Préférences",
            "zh-Hans": "偏好设置",
            "zh-Hant": "偏好設定",
        ],
        .language: [
            "en": "Language",
            "ja": "言語",
            "ko": "언어",
            "fr": "Langue",
            "zh-Hans": "语言",
            "zh-Hant": "語言",
        ],
        .textSize: [
            "en": "Text size",
            "ja": "文字サイズ",
            "ko": "글자 크기",
            "fr": "Taille du texte",
            "zh-Hans": "文字大小",
            "zh-Hant": "文字大小",
        ],
        .textSizeSmall: [
            "en": "Small",
            "ja": "小",
            "ko": "작게",
            "fr": "Petit",
            "zh-Hans": "小",
            "zh-Hant": "小",
        ],
        .textSizeNormal: [
            "en": "Default",
            "ja": "標準",
            "ko": "기본",
            "fr": "Par défaut",
            "zh-Hans": "默认",
            "zh-Hant": "預設",
        ],
        .textSizeLarge: [
            "en": "Large",
            "ja": "大",
            "ko": "크게",
            "fr": "Grand",
            "zh-Hans": "大",
            "zh-Hant": "大",
        ],
        .textSizeExtraLarge: [
            "en": "Extra large",
            "ja": "特大",
            "ko": "아주 크게",
            "fr": "Très grand",
            "zh-Hans": "特大",
            "zh-Hant": "特大",
        ],
        .launchAtLogin: [
            "en": "Launch at login",
            "ja": "ログイン時に起動",
            "ko": "로그인 시 실행",
            "fr": "Lancer à l'ouverture de session",
            "zh-Hans": "登录时启动",
            "zh-Hant": "登入時啟動",
        ],
        .chooseLine: [
            "en": "Choose a line",
            "ja": "路線を選択",
            "ko": "노선 선택",
            "fr": "Choisir une ligne",
            "zh-Hans": "选择线路",
            "zh-Hant": "選擇路線",
        ],
        .noLinesForStation: [
            "en": "No lines found for this station",
            "ja": "この駅を通る路線はありません",
            "ko": "이 역을 지나는 노선이 없습니다",
            "fr": "Aucune ligne pour cette gare",
            "zh-Hans": "没有经过该车站的线路",
            "zh-Hant": "沒有經過該車站的路線",
        ],
        .done: [
            "en": "Done",
            "ja": "完了",
            "ko": "완료",
            "fr": "Terminé",
            "zh-Hans": "完成",
            "zh-Hant": "完成",
        ],
        .searchLines: [
            "en": "Type a line…",
            "ja": "路線を入力…",
            "ko": "노선 입력…",
            "fr": "Saisir une ligne…",
            "zh-Hans": "输入线路…",
            "zh-Hant": "輸入路線…",
        ],
        .searchStations: [
            "en": "Type a station…",
            "ja": "駅を入力…",
            "ko": "역 입력…",
            "fr": "Saisir une gare…",
            "zh-Hans": "输入车站…",
            "zh-Hant": "輸入車站…",
        ],
        .removeBoard: [
            "en": "Remove board",
            "ja": "ボードを削除",
            "ko": "보드 삭제",
            "fr": "Supprimer le tableau",
            "zh-Hans": "删除看板",
            "zh-Hant": "刪除看板",
        ],
        .cancel: [
            "en": "Cancel",
            "ja": "キャンセル",
            "ko": "취소",
            "fr": "Annuler",
            "zh-Hans": "取消",
            "zh-Hant": "取消",
        ],
        .realtimeSection: [
            "en": "Real-time",
            "ja": "リアルタイム",
            "ko": "실시간",
            "fr": "Temps réel",
            "zh-Hans": "实时",
            "zh-Hant": "即時",
        ],
        .apiKeyLabel: [
            "en": "ODPT API key",
            "ja": "ODPT APIキー",
            "ko": "ODPT API 키",
            "fr": "Clé API ODPT",
            "zh-Hans": "ODPT API 密钥",
            "zh-Hant": "ODPT API 金鑰",
        ],
        .apiKeyPrompt: [
            "en": "Paste your consumer key",
            "ja": "コンシューマーキーを貼り付け",
            "ko": "컨슈머 키 붙여넣기",
            "fr": "Collez votre clé",
            "zh-Hans": "粘贴你的密钥",
            "zh-Hant": "貼上你的金鑰",
        ],
        .getFreeKey: [
            "en": "Get a free key at developer.odpt.org",
            "ja": "developer.odpt.org で無料キーを取得",
            "ko": "developer.odpt.org에서 무료 키 받기",
            "fr": "Obtenez une clé gratuite sur developer.odpt.org",
            "zh-Hans": "在 developer.odpt.org 获取免费密钥",
            "zh-Hant": "在 developer.odpt.org 取得免費金鑰",
        ],
        .realtimeOff: [
            "en": "Schedule only — add a key for live status",
            "ja": "時刻表のみ — キーを追加すると運行情報を表示",
            "ko": "시간표만 — 키를 추가하면 운행 정보 표시",
            "fr": "Horaires seuls — ajoutez une clé pour l'état en direct",
            "zh-Hans": "仅时刻表 — 添加密钥以显示运行状态",
            "zh-Hant": "僅時刻表 — 新增金鑰以顯示運行狀態",
        ],
        .realtimeOn: [
            "en": "Live status on",
            "ja": "運行情報：オン",
            "ko": "운행 정보: 켬",
            "fr": "État en direct activé",
            "zh-Hans": "实时状态已开启",
            "zh-Hant": "即時狀態已開啟",
        ],
        .settingsWindowTitle: [
            "en": "TrainMenu Settings",
            "ja": "TrainMenu 設定",
            "ko": "TrainMenu 설정",
            "fr": "Réglages TrainMenu",
            "zh-Hans": "TrainMenu 设置",
            "zh-Hant": "TrainMenu 設定",
        ],
        .normalService: [
            "en": "Normal service",
            "ja": "平常運転",
            "ko": "정상 운행",
            "fr": "Service normal",
            "zh-Hans": "正常运行",
            "zh-Hant": "正常運行",
        ],
    ]
}
