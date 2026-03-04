// MaxInterstitialAd.swift
// AppLovin MAX 插屏广告
//
// MAX API 对应：
//   InterstitialAd.load()   →  MAInterstitialAd.loadAd()
//   ad.present(from:)       →  interstitial.showAd(forPlacement:customData:viewController:)
//   FullScreenContentDelegate → MAAdDelegate + MAAdRequestDelegate（合并在同一 extension）

import Foundation
import UIKit
import AppLovinSDK

public final class MaxInterstitialAd: MaxAds, FullScreenAd {

    

    public override var format: AdFormat { .ad_interstitial }

    private var interstitial: MAInterstitialAd?
    // continuation 用于将 MAX delegate 回调桥接到 async/await
    private var loadContinuation: CheckedContinuation<Bool, Error>?

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else {
                cont.resume(throwing: AdLoadException(code: AdLoadException.CODE_SDK_ERROR, msg: "self released"))
                return
            }
            self.loadContinuation = cont

            // MAX 插屏必须在主线程创建
            let ad = MAInterstitialAd(adUnitIdentifier: self.adUnit.adId)
            ad.delegate = self
            ad.revenueDelegate = self
            self.interstitial = ad
            ad.load()
        }
    }
    // MARK: - Show

    @discardableResult
    public func show(from viewController: UIViewController?) -> Bool {
        guard let ad = interstitial, ad.isReady else { return false }
        ad.show(forPlacement: currentAdScene?.sceneName, customData: nil, viewController: viewController)
        return true
    }

    // MARK: - Cleanup

    public override func destroy() {
        interstitial?.delegate = nil
        interstitial?.revenueDelegate = nil
        interstitial = nil
        loadContinuation = nil
    }

    public override func clearAdInstance() {
        interstitial = nil
    }

    public override func retrieveAd() -> Any? { interstitial?.isReady == true ? interstitial : nil }
}

// MARK: - MAAdDelegate

extension MaxInterstitialAd: MAAdDelegate {
    public func didFail(toDisplay ad: MAAd, withError error: MAError) {
        clearAdInstance()
        delegate.onAdFailedToShow()
    }
    

    public func didLoad(_ ad: MAAd) {
        markReady()
        SilverAdLog.d("MaxInterstitialAd: didLoad (\(adUnit))")
        loadContinuation?.resume(returning: true)
        loadContinuation = nil
    }

    public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        SilverAdLog.d("MaxInterstitialAd: didFailToLoad [\(error.code.rawValue)] \(error.message)")
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
}

// MARK: - MAAdRevenueDelegate

extension MaxInterstitialAd: MAAdRevenueDelegate {
    public func didPayRevenue(for ad: MAAd) {
        updateEventData(with: ad)
        delegate.onAdsPaid()
    }
}
