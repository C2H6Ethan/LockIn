import LockInCore
import MapKit
import Observation

/// Address and point-of-interest search for the place picker.
@MainActor
@Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Hashable {
        let title: String
        let subtitle: String
    }

    private(set) var suggestions: [Suggestion] = []
    var query = "" {
        didSet { query.isEmpty ? (suggestions = []) : (completer.queryFragment = query) }
    }

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let items = completer.results.prefix(8).map { Suggestion(title: $0.title, subtitle: $0.subtitle) }
        MainActor.assumeIsolated { suggestions = items }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { suggestions = [] }
    }

    /// Looks up the coordinate of a suggestion.
    func resolve(_ suggestion: Suggestion) async -> Place? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = [suggestion.title, suggestion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        guard let item = try? await MKLocalSearch(request: request).start().mapItems.first else { return nil }
        let coordinate = item.placemark.coordinate
        return Place(name: suggestion.title, latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
