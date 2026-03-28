import SwiftUI
import MapKit

struct LocationMapPicker: View {
    let initialLocation: TaskLocation
    let onConfirm: (TaskLocation) -> Void
    let onCancel: () -> Void

    @State private var position: MapCameraPosition
    @State private var centerCoordinate: CLLocationCoordinate2D
    @State private var addressLine: String = ""

    init(
        initialLocation: TaskLocation,
        onConfirm: @escaping (TaskLocation) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialLocation = initialLocation
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let coord = CLLocationCoordinate2D(
            latitude: initialLocation.latitude,
            longitude: initialLocation.longitude
        )
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: coord,
            latitudinalMeters: 400,
            longitudinalMeters: 400
        )))
        _centerCoordinate = State(initialValue: coord)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Map with fixed center pin
            ZStack {
                Map(position: $position)
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .environment(\.colorScheme, .dark)
                    .onMapCameraChange(frequency: .continuous) { ctx in
                        centerCoordinate = ctx.camera.centerCoordinate
                    }
                    .onMapCameraChange(frequency: .onEnd) { ctx in
                        centerCoordinate = ctx.camera.centerCoordinate
                        reverseGeocode(ctx.camera.centerCoordinate)
                    }

                // Fixed pin at map center — user pans map to position it
                VStack(spacing: 0) {
                    Circle()
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    Rectangle()
                        .fill(DesignSystem.Colors.accent)
                        .frame(width: 2, height: 8)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 170)

            // Info + confirm panel
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(initialLocation.name)
                            .font(.system(.caption, weight: .semibold))
                            .foregroundStyle(DesignSystem.Colors.primaryText)
                            .lineLimit(1)
                        Text(addressLine.isEmpty ? "Drag map to adjust pin" : addressLine)
                            .font(.system(.caption2))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                            .animation(.easeOut(duration: 0.15), value: addressLine)
                    }
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                }

                Button {
                    onConfirm(TaskLocation(
                        latitude: centerCoordinate.latitude,
                        longitude: centerCoordinate.longitude,
                        name: initialLocation.name,
                        radius: 200
                    ))
                } label: {
                    Text("Confirm")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.sm - 2)
                        .background(DesignSystem.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
        .onAppear { reverseGeocode(centerCoordinate) }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(
            CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ) { placemarks, _ in
            guard let p = placemarks?.first else { return }
            let parts = [p.thoroughfare, p.locality].compactMap { $0 }
            addressLine = parts.joined(separator: ", ")
        }
    }
}
