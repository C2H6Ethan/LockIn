import SwiftUI
import MapKit
import Observation

// MARK: - View model

@Observable
final class LocationSearchViewModel: NSObject, MKLocalSearchCompleterDelegate {
    var suggestions: [MKLocalSearchCompletion] = []
    var isLoading = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func updateQuery(_ query: String) {
        if query.isEmpty { suggestions = []; return }
        completer.queryFragment = query
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> TaskLocation? {
        isLoading = true
        defer { isLoading = false }
        return await withCheckedContinuation { cont in
            let request = MKLocalSearch.Request(completion: completion)
            MKLocalSearch(request: request).start { response, _ in
                guard let item = response?.mapItems.first else {
                    cont.resume(returning: nil)
                    return
                }
                let coord = item.placemark.coordinate
                cont.resume(returning: TaskLocation(
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    name: completion.title
                ))
            }
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        DispatchQueue.main.async { [weak self] in self?.suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.suggestions = [] }
    }
}

// MARK: - View

struct LocationSearchBar: View {
    @Binding var selectedLocation: TaskLocation?
    @State private var searchVM = LocationSearchViewModel()
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            if let loc = selectedLocation {
                // Collapsed — show selected location with clear button
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text(loc.name)
                        .font(.system(.caption))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        selectedLocation = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(DesignSystem.Colors.secondaryText.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
            } else {
                // Search field
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                    TextField("Search for a place", text: $query)
                        .font(.system(.caption))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .tint(DesignSystem.Colors.accent)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, new in searchVM.updateQuery(new) }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                .background(DesignSystem.Colors.secondaryText.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))

                // Suggestions (max 3)
                if !searchVM.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(searchVM.suggestions.prefix(3).enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                _Concurrency.Task {
                                    if let loc = await searchVM.resolve(suggestion) {
                                        selectedLocation = loc
                                        query = ""
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.title)
                                        .font(.system(.caption))
                                        .foregroundStyle(DesignSystem.Colors.primaryText)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.system(.caption2))
                                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                }
            }
        }
    }
}
