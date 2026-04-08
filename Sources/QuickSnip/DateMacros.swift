import Foundation

/// Processes TextExpander-style date/time format codes in a snippet expansion string.
/// Supports the same codes as the original TextExpander (strftime-compatible + TE extras).
enum DateMacros {

    static func process(_ text: String) -> String {
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        var result = text

        // --- Year ---
        result = result.replacingOccurrences(of: "%Y", with: String(format: "%04d", comps.year ?? 0))
        result = result.replacingOccurrences(of: "%y", with: String(format: "%02d", (comps.year ?? 0) % 100))

        // --- Month ---
        formatter.dateFormat = "MMMM"
        result = result.replacingOccurrences(of: "%B", with: formatter.string(from: now))
        formatter.dateFormat = "MMM"
        result = result.replacingOccurrences(of: "%b", with: formatter.string(from: now))
        result = result.replacingOccurrences(of: "%1m", with: String(comps.month ?? 0))   // no leading zero (TE-specific)
        result = result.replacingOccurrences(of: "%m", with: String(format: "%02d", comps.month ?? 0))

        // --- Day ---
        result = result.replacingOccurrences(of: "%e", with: String(comps.day ?? 0))      // no leading zero
        result = result.replacingOccurrences(of: "%d", with: String(format: "%02d", comps.day ?? 0))

        // --- Weekday ---
        formatter.dateFormat = "EEEE"
        result = result.replacingOccurrences(of: "%A", with: formatter.string(from: now))
        formatter.dateFormat = "EEE"
        result = result.replacingOccurrences(of: "%a", with: formatter.string(from: now))

        // --- Hour ---
        let hour = comps.hour ?? 0
        let hour12raw = hour % 12
        let hour12 = hour12raw == 0 ? 12 : hour12raw
        result = result.replacingOccurrences(of: "%H", with: String(format: "%02d", hour))
        result = result.replacingOccurrences(of: "%1I", with: String(hour12))             // 12-hr no leading zero (TE-specific, must come before %I)
        result = result.replacingOccurrences(of: "%I", with: String(format: "%02d", hour12))

        // --- Minute / Second ---
        result = result.replacingOccurrences(of: "%M", with: String(format: "%02d", comps.minute ?? 0))
        result = result.replacingOccurrences(of: "%S", with: String(format: "%02d", comps.second ?? 0))

        // --- AM/PM ---
        result = result.replacingOccurrences(of: "%p", with: hour < 12 ? "AM" : "PM")
        result = result.replacingOccurrences(of: "%P", with: hour < 12 ? "am" : "pm")

        return result
    }
}
