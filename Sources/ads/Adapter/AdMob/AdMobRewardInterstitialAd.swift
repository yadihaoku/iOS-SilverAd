// AdMobRewardInterstitialAd.swift
// Translated from AdMobRewardInterstitialAd.kt
//
// 翻译说明：
// - RewardedInterstitialAd.load    →  RewardedInterstitialAd.load(withAdUnitID:request:completionHandler:)
// - ad.show(activity, rewardListener) →  ad.present(fromRootViewController:userDidEarnRewardHandler:)

import Foundation
import UIKit
import GoogleMobileAds

public final class AdMobRewardInterstitialAd: AdMobAds, FullScreenAd {

    public override var format: AdFormat { .ad_reward_interstitial }

    private var rewardedInterstitialAd: RewardedInterstitialAd?

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { cont in
            let request = AdManagerRequest()
            RewardedInterstitialAd.load(
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
                Task{@MainActor in
                    self.rewardedInterstitialAd = ad
                    self.updateEventData(with: ad?.responseInfo)
                    self.markReady()
                    cont.resume(returning: true)
                }
            }
        }
    }

    // MARK: - Show

    @discardableResult
    public func show(from viewController: UIViewController?) -> Bool {
        guard let ad = rewardedInterstitialAd else { return false }
        ad.fullScreenContentDelegate = fullScreenCallbackWrapper
        ad.paidEventHandler = { [weak self] paidEvent in
            self?.fullScreenCallbackWrapper.onPaidEvent(paidEvent)
        }
        ad.present(from: viewController) { [weak self] in
            self?.fullScreenCallbackWrapper.onUserEarnedReward()
        }
        return true
    }

    // MARK: - Cleanup

    public override func destroy() {
        Task{@MainActor in
            rewardedInterstitialAd?.fullScreenContentDelegate = nil
            rewardedInterstitialAd?.paidEventHandler = nil
            rewardedInterstitialAd = nil
        }
    }

    public override func clearAdInstance() {
        rewardedInterstitialAd = nil
    }

    public override func retrieveAd() -> Any? { rewardedInterstitialAd }
}
