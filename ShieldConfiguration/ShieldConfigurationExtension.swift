import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private var store: SharedStore { SharedStore(suiteName: Constants.AppGroup.id) }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    // MARK: - Private

    private func makeConfiguration() -> ShieldConfiguration {
        let tasks = store.incompleteBlockingTasks
        let subtitle = Constants.ShieldDisplay.subtitleText(for: tasks)
        let steps = store.stepsRequired
        let secondaryLabel = "\(steps) steps to earn access"

        let background = UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)   // #0A0A0A
        let primary    = UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)   // #F5F5F0
        let secondary  = UIColor(red: 0.42, green: 0.42, blue: 0.42, alpha: 1)   // #6B6B6B
        let accent     = UIColor(red: 0.91, green: 0.84, blue: 0.64, alpha: 1)   // #E8D5A3

        var logo: UIImage? = nil
        if let path = Bundle.main.path(forResource: "ShieldLogo", ofType: "png") {
            logo = UIImage(contentsOfFile: path)
        }

        return ShieldConfiguration(
            backgroundColor: background,
            icon: logo,
            title: ShieldConfiguration.Label(
                text: Constants.ShameMessages.random(),
                color: primary
            ),
            subtitle: subtitle.isEmpty ? nil : ShieldConfiguration.Label(
                text: subtitle,
                color: secondary
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: Constants.ShieldDisplay.primaryButton,
                color: background
            ),
            primaryButtonBackgroundColor: accent,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: secondaryLabel,
                color: primary
            )
        )
    }
}
