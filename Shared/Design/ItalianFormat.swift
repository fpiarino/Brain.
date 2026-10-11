import Foundation

/// Testi e date in italiano, indipendenti dalla lingua impostata sul telefono.
enum ItalianFormat {
    private static let locale = Locale(identifier: "it_IT")

    private static func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = .brain
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = template
        return formatter
    }

    private static let weekdayDayMonth = formatter("EEEE d MMMM")
    private static let dayMonth = formatter("d MMMM")
    private static let shortDayMonth = formatter("d MMM")
    private static let monthYear = formatter("LLLL yyyy")
    private static let fullDate = formatter("d MMMM yyyy")

    /// "Domenica 11 ottobre"
    static func weekdayTitle(_ day: DayKey) -> String {
        capitalized(weekdayDayMonth.string(from: day.startDate()))
    }

    /// "11 ottobre"
    static func dayMonthText(_ day: DayKey) -> String {
        dayMonth.string(from: day.startDate())
    }

    /// "11 ott"
    static func shortDayMonthText(_ day: DayKey) -> String {
        shortDayMonth.string(from: day.startDate())
    }

    /// "11 ottobre 2026"
    static func fullDateText(_ day: DayKey) -> String {
        fullDate.string(from: day.startDate())
    }

    /// "Ottobre 2026"
    static func monthTitle(_ month: YearMonth) -> String {
        capitalized(monthYear.string(from: month.firstDay.startDate()))
    }

    /// "1 giorno", "5 giorni"
    static func days(_ count: Int) -> String {
        count == 1 ? "1 giorno" : "\(count) giorni"
    }

    static func statusText(_ status: DayStatus?) -> String {
        switch status {
        case .done?: "fatto"
        case .missed?: "non fatto"
        case .paused?: "in pausa"
        case nil: "non registrato"
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    /// "1.800", "7,5"
    static func number(_ value: Double) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Numero per un campo di testo modificabile, senza separatori delle migliaia ("1800", "7,5").
    static func editableNumber(_ value: Double) -> String {
        let text = value.rounded() == value ? String(Int(value)) : String(value)
        return text.replacingOccurrences(of: ".", with: ",")
    }

    /// "settimana dal 5 ott"
    static func weekText(_ weekStart: DayKey) -> String {
        "settimana dal \(shortDayMonthText(weekStart))"
    }

    /// "Lunedì" … "Domenica" (1 = lunedì).
    static func weekdayName(_ isoWeekday: Int) -> String {
        let names = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
        return names[min(max(isoWeekday, 1), 7) - 1]
    }

    /// "L", "M", "M", "G", "V", "S", "D"
    static let weekdayInitials = ["L", "M", "M", "G", "V", "S", "D"]

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
