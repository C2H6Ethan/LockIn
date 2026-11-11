import LockInCore
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Styles Apple's Shield template with LockIn's colors and copy. No custom UI is possible here (see CLAUDE.md).
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration { make() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { make() }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { make() }

    private func make() -> ShieldConfiguration {
        var rng = SystemRandomNumberGenerator()
        let subtitle = ShieldCopy.subtitle(owed: owedTitles(), using: &rng)
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor(Palette.background),
            icon: UIImage(named: "ShieldLogo") ?? Bundle.main.path(forResource: "ShieldLogo", ofType: "png").flatMap(UIImage.init(contentsOfFile:)),
            title: .init(text: ShieldCopy.title(using: &rng), color: UIColor(Palette.primaryText)),
            subtitle: subtitle.map { .init(text: $0, color: UIColor(Palette.secondaryText)) },
            primaryButtonLabel: .init(text: ShieldCopy.primaryButton, color: UIColor(Palette.background)),
            primaryButtonBackgroundColor: UIColor(Palette.accent),
            secondaryButtonLabel: .init(text: ShieldCopy.secondaryButton, color: UIColor(Palette.primaryText))
        )
    }

    private func owedTitles() -> [String] {
        guard let storage = UserDefaultsStorage.appGroup() else { return [] }
        let store = LockInStore(storage: storage)
        return ShieldDecision.owedTasks(at: Date(), tasks: store.read(.tasks), completions: store.read(.completions), calendar: .current)
            .map(\.title)
    }
}

private extension UIColor {
    convenience init(_ rgb: Palette.RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
