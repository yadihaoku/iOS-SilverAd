// MaxRewardAd.swift
// AppLovin MAX 激励广告
//
// MAX API 对应：
//   RewardedAd.load()         →  MARewardedAd.shared(withAdUnitIdentifier:).loadAd()
//   present(userDidEarnReward) →  showAd(forPlacement:...) + MARewardedAdDelegate.didRewardUser

import Foundation
import UIKit
import AppLovinSDK

public final class MaxRewardAd: MaxAds, FullScreenAd {

    public override var format: AdFormat { .ad_reward }

    private var rewardedAd: MARewardedAd?
    private var loadContinuation: CheckedContinuation<Bool, Error>?

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else {
                cont.resume(throwing: AdLoadException(code: AdLoadException.CODE_SDK_ERROR, msg: "self released"))
                return
            }
            self.loadContinuation = cont

            // MAX 激励广告使用单例 shared(withAdUnitIdentifier:)
            let ad = MARewardedAd.shared(withAdUnitIdentifier: self.adUnit.adId)
            ad.delegate = self
            ad.revenueDelegate = self
            self.rewardedAd = ad
            ad.load()
        }
    }

    // MARK: - Show

    @discardableResult
    public func show(from viewController: UIViewController?) -> Bool {
        guard let ad = rewardedAd, ad.isReady else { return false }
        ad.show(forPlacement: currentAdScene?.sceneName, customData: nil, viewController: viewController)
        return true
    }

    // MARK: - Cleanup

    public override func destroy() {
        rewardedAd?.delegate = nil
        rewardedAd?.revenueDelegate = nil
        rewardedAd = nil
        loadContinuation = nil
    }

    public override func clearAdInstance() {
        rewardedAd = nil
    }

    public override func retrieveAd() -> Any? { rewardedAd?.isReady == true ? rewardedAd : nil }
}

// MARK: - MARewardedAdDelegate

extension MaxRewardAd: MARewardedAdDelegate {
    public func didFail(toDisplay ad: MAAd, withError error: MAError) {
        clearAdInstance()
        delegate.onAdFailedToShow()
    }
    

    public func didLoad(_ ad: MAAd) {
        markReady()
        SilverAdLog.d("MaxRewardAd: didLoad (\(adUnit))")
        loadContinuation?.resume(returning: true)
        loadContinuation = nil
    }

    public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        SilverAdLog.d("MaxRewardAd: didFailToLoad [\(error.code.rawValue)] \(error.message)")
        loadContinuation?.resume(throwing: AdLoadException(
            code: AdLoadException.CODE_SDK_ERROR,
            msg: "[\(error.code.rawValue)] \(error.message)"
        ))
        loadContinuation = nil
    }

    public func didDisplay(_ ad: MAAd) {
        delegate.onAdShowed()
        delegate.onAdImpression()
    }

 

    public func didClick(_ ad: MAAd) {
        delegate.onAdClicked()
    }

    public func didHide(_ ad: MAAd) {
        clearAdInstance()
        delegate.onAdClosed()
    }

    /// 激励回调（对应 AdMob 的 userDidEarnRewardHandler）
    public func didRewardUser(for ad: MAAd, with reward: MAReward) {
        SilverAdLog.d("MaxRewardAd: didRewardUser label=\(reward.label) amount=\(reward.amount)")
        delegate.onReward()
    }
}

// MARK: - MAAdRevenueDelegate

extension MaxRewardAd: MAAdRevenueDelegate {
    public func didPayRevenue(for ad: MAAd) {
        updateEventData(with: ad)
    }
}
