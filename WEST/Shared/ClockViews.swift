import SwiftUI

/// A discrete style keeps TimeDataSource live while applying the selected IANA
/// zone itself. Date.FormatStyle was formatted in the Mac zone by SwiftUI on
/// the tested macOS build even though its `timeZone` property was populated.
struct ZonedTimeStyle: DiscreteFormatStyle {
    typealias FormatInput = Date
    typealias FormatOutput = String

    let zoneID: String
    let language: String
    let hourFormat: HourFormat
    let seconds: Bool

    func format(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = hourFormat == .system
            ? .autoupdatingCurrent
            : Locale(identifier: Localization.resolved(language))
        formatter.timeZone = TimeZone(identifier: zoneID)
        switch hourFormat {
        case .system:
            formatter.timeStyle = seconds ? .medium : .short
            formatter.dateStyle = .none
        case .twelve:
            formatter.dateFormat = seconds ? "h:mm:ss a" : "h:mm a"
        case .twentyFour:
            formatter.dateFormat = seconds ? "HH:mm:ss" : "HH:mm"
        }
        return formatter.string(from: value)
    }

    private var step: TimeInterval { seconds ? 1 : 60 }
    func discreteInput(after input: Date) -> Date? {
        Date(timeIntervalSinceReferenceDate:
                (input.timeIntervalSinceReferenceDate / step).rounded(.down) * step + step)
    }
    func discreteInput(before input: Date) -> Date? {
        let boundary = (input.timeIntervalSinceReferenceDate / step).rounded(.down) * step
        return Date(timeIntervalSinceReferenceDate:
                boundary < input.timeIntervalSinceReferenceDate ? boundary : boundary - step)
    }
}

struct LiveClock: View {
    let record: ClockRecord
    let preferences: Preferences
    var body: some View {
        Text(TimeDataSource<Date>.currentDate,
             format: ZonedTimeStyle(zoneID: record.zoneID,
                                    language: preferences.language,
                                    hourFormat: preferences.format,
                                    seconds: preferences.seconds))
            .monospacedDigit()
    }
}
struct ClockRow: View {
    let record: ClockRecord
    let preferences: Preferences
    let date: Date
    var compact = false
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: record.title(at: date)).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 4) {
                    if record.kind == .city { Text(verbatim: record.abbreviation(at: date)) }
                    Text(verbatim: Localization.utc(record.zone.secondsFromGMT(for: date)))
                }.font(compact ? .system(size: 10) : .caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                LiveClock(record: record, preferences: preferences)
                    .font(.system(size: compact ? 19 : 28, weight: .medium, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
                Text(verbatim: Localization.difference(record.difference(at: date), language: preferences.language))
                    .font(compact ? .system(size: 11) : .caption).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}
struct Countdown: View {
    let timer: TimerState
    let now: Date
    var body: some View {
        if timer.effectivePhase(at: now) == .running, let deadline = timer.deadline {
            Text(timerInterval: now...max(now, deadline), countsDown: true, showsHours: true).monospacedDigit()
        } else {
            let seconds = Int(ceil(timer.remaining(at: now)))
            Text(verbatim: String(format: "%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)).monospacedDigit()
        }
    }
}
