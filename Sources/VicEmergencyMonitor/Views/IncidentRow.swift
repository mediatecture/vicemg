import SwiftUI

struct IncidentRow: View {
    let incident: Incident
    let distanceKm: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(incident.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    if let distanceKm {
                        Text(String(format: "%.0f km", distanceKm))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if incident.detailURL != nil {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(incident.displayLocation)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(incident.severityLabel)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.18))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                    if !incident.isOfficialWarning, let status = incident.status {
                        Text(status)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let updated = incident.updatedDate {
                        Text(updated.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var color: Color {
        switch incident.severity {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .gray
        }
    }
}
