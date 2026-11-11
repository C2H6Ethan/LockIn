import LockInCore
import MapKit
import SwiftUI

/// Search for a place, then fine-tune the pin by tapping the map.
struct PlacePickerView: View {
    let initial: Place?
    let onPick: (Place) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearch()
    @State private var place: Place?
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                TextField("Search for a place", text: $search.query)
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                if searchFocused || place == nil {
                    suggestions
                } else if let place {
                    map(for: place)
                }
            }
            .padding(.top, DesignSystem.Spacing.md)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(DesignSystem.Colors.background)
            .navigationTitle("Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(DesignSystem.Colors.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        if let place { onPick(place) }
                        dismiss()
                    }
                    .disabled(place == nil)
                }
            }
        }
        .tint(DesignSystem.Colors.accent)
        .onAppear {
            place = initial
            if let initial { focus(on: initial) } else { searchFocused = true }
        }
    }

    private var suggestions: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(search.suggestions, id: \.self) { suggestion in
                    Button {
                        Task {
                            guard let resolved = await search.resolve(suggestion) else { return }
                            place = resolved
                            focus(on: resolved)
                            searchFocused = false
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(suggestion.title).foregroundStyle(DesignSystem.Colors.primaryText)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
    }

    private func map(for place: Place) -> some View {
        let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            MapReader { proxy in
                Map(position: $camera) {
                    MapCircle(center: center, radius: Place.radius)
                        .foregroundStyle(DesignSystem.Colors.accent.opacity(0.2))
                    Marker(place.name, coordinate: center)
                        .tint(DesignSystem.Colors.accent)
                }
                .onTapGesture { point in
                    guard let tapped = proxy.convert(point, from: .local) else { return }
                    self.place = Place(name: place.name, latitude: tapped.latitude, longitude: tapped.longitude)
                }
            }
            .frame(maxHeight: .infinity)
            Text("Tap the map to move the pin. Counts within \(Int(Place.radius)) m.")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
        }
    }

    private func focus(on place: Place) {
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            latitudinalMeters: 800, longitudinalMeters: 800
        ))
    }
}
