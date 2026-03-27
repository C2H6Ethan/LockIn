import StoreKit
import UIKit

enum ReviewManager {

    static let flagKey = "hasRequestedReview7Day"

    /// Call after every streak update. Requests a review exactly once when streak hits 7.
    static func requestIfEligible(
        currentStreak: Int,
        defaults: UserDefaults = .standard,
        requestReview: (() -> Void)? = nil
    ) {
        guard currentStreak == 7 else { return }
        guard !defaults.bool(forKey: flagKey) else { return }
        defaults.set(true, forKey: flagKey)

        let trigger = requestReview ?? {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                guard let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
                else { return }
                SKStoreReviewController.requestReview(in: scene)
            }
        }
        trigger()
    }
}
