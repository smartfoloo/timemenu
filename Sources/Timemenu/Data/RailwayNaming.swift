import Foundation

/// Hand-authored naming corrections layered on top of the raw ODPT metadata.
///
/// Two distinct problems this fixes:
///  1. Some line titles are ambiguous or inaccurate without their operator
///     (e.g. "銀座線", "池袋線", "羽田空港線"). `titleOverrides` supplies the
///     corrected display title, which replaces the metadata title everywhere.
///  2. The raw operator id ("TokyoMetro", "JR-East") is not a real localized
///     name. `operatorNames` maps each operator id prefix to a proper name.
///
/// Per project decision these are authored for Japanese + English only; other
/// languages fall back to the English value (see `Localized.localized`). JR
/// lines are intentionally left alone — they're commonly referred to by their
/// own name without the "JR" prefix — except where a line needs it (e.g. the
/// Sotetsu through-service line below).
enum RailwayNaming {

    /// railwayId -> corrected localized title. Curated, not generated: each
    /// entry is a deliberate correction. Extend as needed.
    static let titleOverrides: [String: Localized] = build([
        // Tokyo Metro — every line is universally prefixed with 東京メトロ.
        ("TokyoMetro.Ginza",            "東京メトロ銀座線",        "Tokyo Metro Ginza Line"),
        ("TokyoMetro.Marunouchi",       "東京メトロ丸ノ内線",       "Tokyo Metro Marunouchi Line"),
        ("TokyoMetro.MarunouchiBranch", "東京メトロ丸ノ内線支線",     "Tokyo Metro Marunouchi Branch Line"),
        ("TokyoMetro.Hibiya",           "東京メトロ日比谷線",       "Tokyo Metro Hibiya Line"),
        ("TokyoMetro.Tozai",            "東京メトロ東西線",        "Tokyo Metro Tozai Line"),
        ("TokyoMetro.Chiyoda",          "東京メトロ千代田線",       "Tokyo Metro Chiyoda Line"),
        ("TokyoMetro.Yurakucho",        "東京メトロ有楽町線",       "Tokyo Metro Yurakucho Line"),
        ("TokyoMetro.Hanzomon",         "東京メトロ半蔵門線",       "Tokyo Metro Hanzomon Line"),
        ("TokyoMetro.Namboku",          "東京メトロ南北線",        "Tokyo Metro Namboku Line"),
        ("TokyoMetro.Fukutoshin",       "東京メトロ副都心線",       "Tokyo Metro Fukutoshin Line"),

        // Seibu — bare line names that need the 西武 prefix. Lines that already
        // carry it (西武秩父線, 西武有楽町線, 西武園線) are left untouched.
        ("Seibu.Ikebukuro",             "西武池袋線",           "Seibu Ikebukuro Line"),
        ("Seibu.Toshima",               "西武豊島線",           "Seibu Toshima Line"),
        ("Seibu.Sayama",                "西武狭山線",           "Seibu Sayama Line"),
        ("Seibu.S-Fukutoshin",          "西武池袋線",           "Seibu Ikebukuro Line"),
        ("Seibu.S-Yurakucho",           "西武池袋線",           "Seibu Ikebukuro Line"),
        ("Seibu.Shinjuku",              "西武新宿線",           "Seibu Shinjuku Line"),
        ("Seibu.Haijima",               "西武拝島線",           "Seibu Haijima Line"),
        ("Seibu.Tamako",                "西武多摩湖線",          "Seibu Tamako Line"),
        ("Seibu.Kokubunji",             "西武国分寺線",          "Seibu Kokubunji Line"),
        ("Seibu.Tamagawa",              "西武多摩川線",          "Seibu Tamagawa Line"),
        ("Seibu.Yamaguchi",             "西武山口線",           "Seibu Yamaguchi Line"),

        // Tokyu — bare lines take 東急. 東急新横浜線 / 東急多摩川線 already carry it.
        ("Tokyu.Toyoko",                "東急東横線",           "Tokyu Toyoko Line"),
        ("Tokyu.DenEnToshi",            "東急田園都市線",         "Tokyu Den-En-Toshi Line"),
        ("Tokyu.Meguro",                "東急目黒線",           "Tokyu Meguro Line"),
        ("Tokyu.Oimachi",               "東急大井町線",          "Tokyu Oimachi Line"),
        ("Tokyu.Ikegami",               "東急池上線",           "Tokyu Ikegami Line"),
        ("Tokyu.Kodomonokuni",          "東急こどもの国線",        "Tokyu Kodomonokuni Line"),
        ("Tokyu.Setagaya",              "東急世田谷線",          "Tokyu Setagaya Line"),

        // Tobu — bare lines take 東武. スカイツリーライン / アーバンパークライン stay branded.
        ("Tobu.Isesaki",                "東武伊勢崎線",          "Tobu Isesaki Line"),
        ("Tobu.Sano",                   "東武佐野線",           "Tobu Sano Line"),
        ("Tobu.Koizumi",                "東武小泉線",           "Tobu Koizumi Line"),
        ("Tobu.KoizumiBranch",          "東武小泉線(東小泉-太田)",   "Tobu Koizumi Line (Higashi-Koizumi–Ota)"),
        ("Tobu.Kiryu",                  "東武桐生線",           "Tobu Kiryu Line"),
        ("Tobu.Nikko",                  "東武日光線",           "Tobu Nikko Line"),
        ("Tobu.JRTobuConnection",       "東武日光線",           "Tobu Nikko Line"),
        ("Tobu.Utsunomiya",             "東武宇都宮線",          "Tobu Utsunomiya Line"),
        ("Tobu.Kinugawa",               "東武鬼怒川線",          "Tobu Kinugawa Line"),
        ("Tobu.Kameido",                "東武亀戸線",           "Tobu Kameido Line"),
        ("Tobu.Daishi",                 "東武大師線",           "Tobu Daishi Line"),
        ("Tobu.Tojo",                   "東武東上線",           "Tobu Tojo Line"),
        ("Tobu.Ogose",                  "東武越生線",           "Tobu Ogose Line"),

        // Keisei — bare lines take 京成. 京成本線 already carries it.
        ("Keisei.HigashiNarita",        "京成東成田線",          "Keisei Higashi-Narita Line"),
        ("Keisei.Oshiage",              "京成押上線",           "Keisei Oshiage Line"),
        ("Keisei.Chiba",                "京成千葉線",           "Keisei Chiba Line"),
        ("Keisei.Chihara",              "京成千原線",           "Keisei Chihara Line"),
        ("Keisei.NaritaSkyAccess",      "京成成田スカイアクセス線",    "Keisei Narita Sky Access Line"),
        ("Keisei.Kanamachi",            "京成金町線",           "Keisei Kanamachi Line"),
        ("Keisei.Matsudo",              "京成松戸線",           "Keisei Matsudo Line"),

        // Keio — bare lines take 京王. 京王線 / 京王新線 already carry it.
        ("Keio.Sagamihara",             "京王相模原線",          "Keio Sagamihara Line"),
        ("Keio.Keibajo",                "京王競馬場線",          "Keio Keibajō Line"),
        ("Keio.Dobutsuen",              "京王動物園線",          "Keio Dōbutsuen Line"),
        ("Keio.Takao",                  "京王高尾線",           "Keio Takao Line"),
        ("Keio.Inokashira",             "京王井の頭線",          "Keio Inokashira Line"),

        // Keikyu — bare lines take 京急. 京急本線 already carries it.
        ("Keikyu.Airport",              "京急空港線",           "Keikyu Airport Line"),
        ("Keikyu.Daishi",               "京急大師線",           "Keikyu Daishi Line"),
        ("Keikyu.Zushi",                "京急逗子線",           "Keikyu Zushi Line"),
        ("Keikyu.Kurihama",             "京急久里浜線",          "Keikyu Kurihama Line"),

        // Odakyu — bare lines take 小田急. (Hakone Tozan is a separate operator.)
        ("Odakyu.Odawara",              "小田急小田原線",         "Odakyu Odawara Line"),
        ("Odakyu.Tama",                 "小田急多摩線",          "Odakyu Tama Line"),
        ("Odakyu.Enoshima",             "小田急江ノ島線",         "Odakyu Enoshima Line"),
        ("Odakyu.JROdakyuConnection",   "小田急小田原線",         "Odakyu Odawara Line"),

        // Sotetsu — 相鉄本線 / 相鉄新横浜線 already carry it; いずみ野線 needs it.
        ("Sotetsu.Izumino",             "相鉄いずみ野線",         "Sotetsu Izumino Line"),

        // Toei subway — standard 都営 prefix. The Nippori-Toneri Liner and the
        // Tokyo Sakura Tram (Arakawa Line) keep their branded names.
        ("Toei.Asakusa",                "都営浅草線",           "Toei Asakusa Line"),
        ("Toei.Mita",                   "都営三田線",           "Toei Mita Line"),
        ("Toei.Shinjuku",               "都営新宿線",           "Toei Shinjuku Line"),
        ("Toei.Oedo",                   "都営大江戸線",          "Toei Oedo Line"),

        // One-off corrections.
        ("TokyoMonorail.HanedaAirport", "東京モノレール",         "Tokyo Monorail"),
        ("JR-East.SotetsuDirect",       "相鉄・JR直通線",        "Sotetsu–JR Direct Line"),
    ])

    /// operator id prefix -> localized operator name. Shown as the secondary
    /// label in the line picker. ja + en authored; other languages fall back to
    /// the English value, then to `fallbackOperatorName`.
    static let operatorNames: [String: Localized] = build([
        ("ChibaMonorail",       "千葉都市モノレール",      "Chiba Monorail"),
        ("Chichibu",            "秩父鉄道",          "Chichibu Railway"),
        ("Choshi",              "銚子電鉄",          "Choshi Electric Railway"),
        ("Enoden",              "江ノ島電鉄",         "Enoshima Electric Railway"),
        ("Fujikyu",             "富士急行",          "Fujikyu Railway"),
        ("Hitachinaka",         "ひたちなか海浜鉄道",     "Hitachinaka Seaside Railway"),
        ("Hokuso",              "北総鉄道",          "Hokuso Railway"),
        ("Isumi",               "いすみ鉄道",         "Isumi Railway"),
        ("IzuHakone",           "伊豆箱根鉄道",        "Izuhakone Railway"),
        ("Izukyu",              "伊豆急行",          "Izukyu"),
        ("JR-Central",          "JR東海",          "JR Central"),
        ("JR-East",             "JR東日本",         "JR East"),
        ("KantoRailway",        "関東鉄道",          "Kanto Railway"),
        ("KashimaRinkai",       "鹿島臨海鉄道",        "Kashima Rinkai Railway"),
        ("Keikyu",              "京急",            "Keikyu"),
        ("Keio",                "京王",            "Keio"),
        ("Keisei",              "京成",            "Keisei"),
        ("Kominato",            "小湊鉄道",          "Kominato Railway"),
        ("MIR",                 "つくばエクスプレス",     "Tsukuba Express"),
        ("Minatomirai",         "横浜高速鉄道",        "Yokohama Minatomirai Railway"),
        ("Moka",                "真岡鐵道",          "Moka Railway"),
        ("Odakyu",              "小田急",           "Odakyu"),
        ("OdakyuHakone",        "箱根登山鉄道",        "Hakone Tozan Railway"),
        ("Ryutetsu",            "流鉄",            "Ryutetsu"),
        ("SaitamaRailway",      "埼玉高速鉄道",        "Saitama Railway"),
        ("SaitamaTransit",      "埼玉新都市交通",       "Saitama New Urban Transit"),
        ("Seibu",               "西武鉄道",          "Seibu Railway"),
        ("Shibayama",           "芝山鉄道",          "Shibayama Railway"),
        ("ShonanMonorail",      "湘南モノレール",       "Shonan Monorail"),
        ("Sotetsu",             "相鉄",            "Sotetsu"),
        ("TWR",                 "東京臨海高速鉄道",      "Tokyo Waterfront Area Rapid Transit"),
        ("TamaMonorail",        "多摩都市モノレール",     "Tama Monorail"),
        ("Tobu",                "東武鉄道",          "Tobu Railway"),
        ("Toei",                "都営",            "Toei"),
        ("TokyoMetro",          "東京メトロ",         "Tokyo Metro"),
        ("TokyoMonorail",       "東京モノレール",       "Tokyo Monorail"),
        ("Tokyu",               "東急",            "Tokyu"),
        ("ToyoRapid",           "東葉高速鉄道",        "Toyo Rapid Railway"),
        ("UtsunomiyaLightRail", "宇都宮ライトレール",     "Utsunomiya Light Rail"),
        ("Yamaman",             "山万",            "Yamaman"),
        ("YokohamaMunicipal",   "横浜市営地下鉄",       "Yokohama Municipal Subway"),
        ("YokohamaSeaside",     "横浜シーサイドライン",    "Yokohama Seaside Line"),
        ("Yurikamome",          "ゆりかもめ",         "Yurikamome"),
    ])

    /// Fallback for operator ids absent from `operatorNames`:
    /// "JR-East" -> "JR East".
    static func fallbackOperatorName(_ id: String) -> String {
        id.replacingOccurrences(of: "-", with: " ")
    }

    private static func build(_ rows: [(String, String, String)]) -> [String: Localized] {
        Dictionary(rows.map { ($0.0, ["ja": $0.1, "en": $0.2]) }, uniquingKeysWith: { a, _ in a })
    }
}
