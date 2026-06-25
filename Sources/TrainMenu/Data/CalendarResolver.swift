import Foundation

/// Decides which timetable calendar ("Weekday", "SaturdayHoliday", ...) applies
/// for a given moment, in Tokyo local time.
///
/// NOTE (Phase 2): Japanese national holidays are not yet handled — only the
/// weekday/Saturday/Sunday split. `isJapaneseHoliday` is the single hook to fill
/// in (fixed-date + Happy-Monday + computed equinox holidays).
enum CalendarResolver {
    static var tokyo: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return c
    }()

    enum DayKind {
        case weekday, saturday, sundayOrHoliday
    }

    static func dayKind(for date: Date) -> DayKind {
        if isJapaneseHoliday(date) { return .sundayOrHoliday }
        switch tokyo.component(.weekday, from: date) {
        case 1: return .sundayOrHoliday   // Sunday
        case 7: return .saturday          // Saturday
        default: return .weekday
        }
    }

    /// Choose the best-matching calendar key from the set a line actually uses.
    static func calendarKey(available: Set<String>, for date: Date) -> String? {
        let order: [String]
        switch dayKind(for: date) {
        case .weekday:
            order = ["Weekday", "SaturdayHoliday"]
        case .saturday:
            order = ["Saturday", "SaturdayHoliday", "Holiday", "Weekday"]
        case .sundayOrHoliday:
            order = ["Holiday", "SaturdayHoliday", "Sunday", "Weekday"]
        }
        return order.first(where: available.contains) ?? available.first
    }

    /// TODO(Phase 2): real Japanese national-holiday calendar.
    static func isJapaneseHoliday(_ date: Date) -> Bool {
        false
    }
}
