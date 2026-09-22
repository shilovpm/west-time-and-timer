import Foundation

enum ClockCatalog {
    static func city(_ name: String, _ country: String, _ zone: String, _ winter: String = "", _ summer: String = "") -> ClockRecord {
        ClockRecord(kind: .city, zoneID: zone, city: name, country: country, winter: winter, summer: summer)
    }
    // These entries add useful aliases in several languages. The rest of the
    // city catalog is generated from Foundation's installed IANA database.
    // IDs stay deterministic for search results; saved records receive their own UUID.
    static let records: [ClockRecord] = {
        var records = [
            city("Berlin", "Germany Deutschland Германия", "Europe/Berlin", "CET", "CEST"),
            city("Paris", "France Франция", "Europe/Paris", "CET", "CEST"),
            city("Rome", "Italy Italia Италия", "Europe/Rome", "CET", "CEST"),
            city("Madrid", "Spain España Испания", "Europe/Madrid", "CET", "CEST"),
            city("Helsinki", "Finland Suomi Финляндия", "Europe/Helsinki", "EET", "EEST"),
            city("Athens", "Greece Ελλάδα Греция", "Europe/Athens", "EET", "EEST"),
            city("Lisbon", "Portugal Lisboa Лиссабон", "Europe/Lisbon", "WET", "WEST"),
            city("London", "United Kingdom UK Великобритания", "Europe/London"),
            city("Moscow", "Russia Россия Москва", "Europe/Moscow"),
            city("Samara", "Russia Россия Самара", "Europe/Samara"),
            city("New York", "United States USA Нью-Йорк", "America/New_York"),
            city("Los Angeles", "United States USA Лос-Анджелес", "America/Los_Angeles"),
            city("São Paulo", "Brazil Brasil Бразилия", "America/Sao_Paulo"),
            city("Tokyo", "Japan 日本 Япония", "Asia/Tokyo"),
            city("Shanghai", "China 中国 Китай", "Asia/Shanghai"),
            city("Kolkata", "India भारत Индия", "Asia/Kolkata"),
            city("Kathmandu", "Nepal नेपाल Непал", "Asia/Kathmandu"),
            city("Dubai", "United Arab Emirates UAE ОАЭ", "Asia/Dubai"),
            city("Sydney", "Australia Австралия", "Australia/Sydney")
        ]

        let curatedZoneIDs = Set(records.map(\.zoneID))
        records += TimeZone.knownTimeZoneIdentifiers
            .filter { !curatedZoneIDs.contains($0) }
            .sorted()
            .map { identifier in
                let pieces = identifier.split(separator: "/")
                let name = (pieces.last.map(String.init) ?? identifier).replacingOccurrences(of: "_", with: " ")
                let area = pieces.dropLast().map(String.init).joined(separator: " ").replacingOccurrences(of: "_", with: " ")
                return city(name, "\(area) \(identifier)", identifier)
            }

        // Human-facing seasonal designations remain independent saved items.
        // Their IANA zones supply the correct DST rules throughout the year.
        records += [("Europe/Berlin", "CET", "CEST"), ("Europe/Helsinki", "EET", "EEST"), ("Europe/Lisbon", "WET", "WEST")].map {
            ClockRecord(kind: .designation, zoneID: $0.0, city: "", country: "", winter: $0.1, summer: $0.2)
        }
        for index in records.indices {
            records[index].id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
        }
        return records
    }()
    static func search(_ query: String, kind: ClockKind, at now: Date) -> [ClockRecord] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let offset = parseUTC(q)
        return records.filter { r in
            guard r.kind == kind else { return false }
            if let offset { return r.zone.secondsFromGMT(for: now) == offset }
            let upper = q.uppercased()
            if upper.hasPrefix("UTC+") || upper.hasPrefix("UTC-") || upper.hasPrefix("UTC−") ||
                upper.hasPrefix("GMT+") || upper.hasPrefix("GMT-") || upper.hasPrefix("GMT−") { return false }
            return q.isEmpty || "\(r.city) \(r.country) \(r.zoneID) \(r.winter) \(r.summer) \(r.abbreviation(at: now))"
                .range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
    static func parseUTC(_ query: String) -> Int? {
        let pattern = #"^(?:UTC|GMT)\s*([+−-])\s*(\d{1,2})(?::?(\d{2}))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let signRange = Range(match.range(at: 1), in: query),
              let hourRange = Range(match.range(at: 2), in: query),
              let hours = Int(query[hourRange]) else { return nil }
        let minutes: Int
        if match.range(at: 3).location == NSNotFound {
            minutes = 0
        } else if let minuteRange = Range(match.range(at: 3), in: query), let value = Int(query[minuteRange]) {
            minutes = value
        } else {
            return nil
        }
        guard
              hours <= 14, minutes < 60, hours < 14 || minutes == 0 else { return nil }
        return (query[signRange] == "+" ? 1 : -1) * (hours * 3600 + minutes * 60)
    }
}
