// MaxSplashAd.swift
// AppLovin MAX 开屏广告（App Open）
//
// MAX 没有独立的 AppOpen 类型；开屏广告通常用插屏广告（MAInterstitialAd）实现：
//   - 加载逻辑与插屏完全相同
//   - 展示时机由业务层控制（App 启动 / 前台时调用 show）
//   - format 标记为 .splash 以便路由区分

import Foundation
import UIKit
import AppLovinSDK

public final class MaxSplashAd: MaxAds, FullScreenAd {

    public override var format: AdFormat { .ad_splash }

    // MAX 复用插屏广告实现开屏
    private var interstitial: MAInterstitialAd?
    private var loadContinuation: CheckedContinuation<Bool, Error>?

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else {
                cont.resume(throwing: AdLoadException(code: AdLoadException.CODE_SDK_ERROR, msg: "self released"))
                return
            }
            self.loadContinuation = cont

            DispatchQueue.main.async {
                let ad = MAInterstitialAd(adUnitIdentifier: self.adUnit.adId)
                ad.delegate = self
                ad.revenueDelegate = self
                self.interstitial = ad
                ad.load()
            }
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

extension MaxSplashAd: MAAdDelegate {
    public func didFail(toDisplay ad: MAAd, withError error: MAError) {
        clearAdInstance()
        delegate.onAdFailedToShow()
    }
    

    public func didLoad(_ ad: MAAd) {
        markReady()
        updateEventData(with: ad)
        SilverAdLog.d("MaxSplashAd: didLoad (\(adUnit))")
        loadContinuation?.resume(returning: true)
        loadContinuation = nil
    }

    public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        SilverAdLog.d("MaxSplashAd: didFailToLoad [\(error.code.rawValue)] \(error.message)")
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

extension MaxSplashAd: MAAdRevenueDelegate {
    public func didPayRevenue(for ad: MAAd) {
        updateEventData(with: ad)
    }
}
