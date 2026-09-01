import Foundation
import CoreLocation

/// GeoJSON response from the OSOM ("One Source One Message") feed that
/// emergency.vic.gov.au's own map runs on.
struct EventsFeedResponse: Decodable {
    let features: [EventFeature]
}

struct EventFeature: Decodable {
    let geometry: EventGeometry
    let properties: EventProperties
}

/// Extracts just the representative point from a GeoJSON geometry — a plain
/// Point, or (for warnings with an affected-area polygon) the Point entry
/// inside a GeometryCollection.
struct EventGeometry: Decodable {
    let coordinate: CLLocationCoordinate2D?

    private enum CodingKeys: String, CodingKey { case type, coordinates, geometries }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "Point":
            let raw = try container.decode([Double].self, forKey: .coordinates)
            coordinate = Self.makeCoordinate(raw)
        case "GeometryCollection":
            // Sub-geometries can be Polygons whose "coordinates" are deeply nested
            // arrays, not [Double] — decode each sub-geometry's `type` only, and
            // only reach into `coordinates` for the one that's a Point.
            var found: CLLocationCoordinate2D?
            if var geometries = try? container.nestedUnkeyedContainer(forKey: .geometries) {
                while !geometries.isAtEnd {
                    let sub = try geometries.nestedContainer(keyedBy: CodingKeys.self)
                    let subType = try sub.decode(String.self, forKey: .type)
                    if subType == "Point", found == nil {
                        let raw = try sub.decode([Double].self, forKey: .coordinates)
                        found = Self.makeCoordinate(raw)
                    }
                }
            }
            coordinate = found
        default:
            coordinate = nil
        }
    }

    private static func makeCoordinate(_ raw: [Double]) -> CLLocationCoordinate2D? {
        guard raw.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: raw[1], longitude: raw[0])
    }
}

struct EventProperties: Decodable {
    let id: String
    let feedType: String
    let category1: String?
    let category2: String?
    let status: String?
    let location: String?
    let name: String?
    let action: String?
    let updated: String?
    let sizeFmt: String?
    let cap: Cap?

    struct Cap: Decodable {
        let severity: String?
        let event: String?
    }
}

/// Domain model combining a feature's coordinate with its properties.
/// `feedType == "warning"` means this is one of VicEmergency's official
/// Advice / Watch and Act / Emergency Warning alerts; anything else is a
/// day-to-day incident (fire, accident, tree down, etc.).
struct Incident: Identifiable, Hashable {
    let id: String
    let feedType: String
    let category1: String?
    let category2: String?
    let status: String?
    let location: String?
    let name: String?
    let action: String?
    let updated: String?
    let sizeFmt: String?
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: Incident, rhs: Incident) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init?(feature: EventFeature) {
        guard let coordinate = feature.geometry.coordinate else { return nil }
        let p = feature.properties
        self.id = p.id
        self.feedType = p.feedType
        self.category1 = p.category1
        self.category2 = p.category2
        self.status = p.status
        self.location = p.location
        self.name = p.name
        self.action = p.action
        self.updated = p.updated
        self.sizeFmt = p.sizeFmt
        self.coordinate = coordinate
    }

    var isOfficialWarning: Bool { feedType == "warning" }

    var displayTitle: String {
        if isOfficialWarning {
            let level = category1 ?? "Warning"
            if let action { return "\(level) — \(action)" }
            return level
        }
        return category2 ?? category1 ?? "Incident"
    }

    var displayLocation: String { location ?? "" }

    var updatedDate: Date? {
        guard let updated else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: updated) ?? ISO8601DateFormatter().date(from: updated)
    }

    /// The URL to this exact incident/warning on the official VicEmergency site.
    var detailURL: URL? {
        switch feedType {
        case "warning":
            return URL(string: "https://emergency.vic.gov.au/respond/#!/warning/\(id)/moreinfo")
        case "incident":
            return URL(string: "https://emergency.vic.gov.au/respond/#!/incident/\(id)")
        default:
            return nil
        }
    }

    enum Severity: Int, Comparable {
        case low = 0, medium = 1, high = 2, critical = 3
        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// For official warnings this reflects the real Advice / Watch and Act /
    /// Emergency Warning escalation. For ordinary incidents it's a heuristic
    /// based on category + status, since the feed has no severity field for those.
    var severity: Severity {
        if isOfficialWarning {
            switch (category1 ?? "").lowercased() {
            case "emergency warning": return .critical
            case "watch and act": return .high
            default: return .medium // Advice
            }
        }
        let cat = (category1 ?? "").lowercased()
        let st = (status ?? "").lowercased()
        let active = st.contains("going") || st.contains("responding") || st.contains("not controlled")
        if cat.contains("fire") {
            if active { return .high }
            if st.contains("control") || st.contains("contain") { return .medium }
            return .low
        }
        if active { return .medium }
        return .low
    }

    /// Authentic official wording for warnings; a plain heuristic label for incidents.
    var severityLabel: String {
        if isOfficialWarning {
            return category1 ?? "Warning"
        }
        switch severity {
        case .critical, .high: return "Active"
        case .medium: return "Contained"
        case .low: return "Minor"
        }
    }
}
