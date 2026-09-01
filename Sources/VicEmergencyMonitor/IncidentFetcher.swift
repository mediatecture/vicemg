import Foundation

/// Polls the OSOM ("One Source One Message") events feed — the same feed that
/// powers the live map at emergency.vic.gov.au — on a timer. This is an
/// unofficial, reverse-engineered endpoint with no documented SLA — treat it as
/// an ambient-awareness source, not a substitute for official VicEmergency alerts.
@MainActor
final class IncidentFetcher: ObservableObject {
    static let feedURL = URL(string: "https://emergency.vic.gov.au/public/events-geojson.json")!

    @Published var incidents: [Incident] = []
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var isFetching: Bool = false

    private var pollTask: Task<Void, Never>?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        stop()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetchOnce()
                let interval = max(15, self.settings.refreshIntervalSeconds)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func fetchOnce() async {
        isFetching = true
        defer { isFetching = false }
        var request = URLRequest(url: Self.feedURL)
        request.setValue("VicEmergencyMonitor/1.0 (personal desktop app)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                errorMessage = "Feed returned HTTP \(http.statusCode)"
                return
            }
            let decoded = try JSONDecoder().decode(EventsFeedResponse.self, from: data)
            incidents = decoded.features.compactMap { Incident(feature: $0) }
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't refresh: \(error.localizedDescription)"
        }
    }
}
