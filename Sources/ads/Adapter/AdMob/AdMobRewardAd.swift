// AdMobRewardAd.swift
// Translated from AdMobRewardAd.kt
//
// 翻译说明：
// - RewardedAd.load(callback)      →  RewardedAd.load(withAdUnitID:request:completionHandler:)
// - ad.show(activity, rewardListener) →  ad.present(fromRootViewController:userDidEarnRewardHandler:)
// - AdManagerAdRequest             →  AdManagerRequest（iOS 对应 Google Ad Manager 请求）

import Foundation
import UIKit
import GoogleMobileAds

public final class AdMobRewardAd: AdMobAds, FullScreenAd {

    public override var format: AdFormat { .ad_reward }

    private var rewardedAd: RewardedAd?

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { cont in
            let request = AdManagerRequest()      // 对应 Kotlin AdManagerAdRequest
            RewardedAd.load(
                with: adUnit.adId,
                request: request
            ) { [weak self] ad, error in
                guard let self else { return }
                if let error {
                    cont.resume(throwing: AdLoadException(
                        code: AdLoadException.CODE_SDK_ERROR,
                        msg: error.localizedDescription
                    ))
                    return
                }
                self.rewardedAd = ad
                self.updateEventData(with: ad?.responseInfo)
                self.markReady()
                cont.resume(returning: true)
            }
        }
    }

    // MARK: - Show

    @discardableResult
    public func show(from viewController: UIViewController?) -> Bool {
        guard let ad = rewardedAd else { return false }
        ad.fullScreenContentDelegate = fullScreenCallbackWrapper
        ad.paidEventHandler = { [weak self] paidEvent in
            self?.fullScreenCallbackWrapper.onPaidEvent(paidEvent)
        }
        // present 的 userDidEarnRewardHandler 对应 OnUserEarnedRewardListener
        ad.present(from: viewController) {
            [weak self] in
                self?.fullScreenCallbackWrapper.onUserEarnedReward()
        }
        return true
    }

    // MARK: - Cleanup

    public override func destroy() {
        Task{@MainActor in
            rewardedAd?.fullScreenContentDelegate = nil
            rewardedAd?.paidEventHandler = nil
            rewardedAd = nil
        }
    }

    public override func clearAdInstance() {
        rewardedAd = nil
    }

    public override func retrieveAd() -> Any? { rewardedAd }
}
