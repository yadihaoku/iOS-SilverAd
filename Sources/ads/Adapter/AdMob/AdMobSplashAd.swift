// AdMobSplashAd.swift
// Translated from AdMobSplashAd.kt
//
// 翻译说明：
// - AppOpenAd.load(context, adId, request, callback)
//     → AppOpenAd.load(withAdUnitID:request:completionHandler:)
// - openAd.show(activity)
//     → openAd.present(fromRootViewController:)
// - AdMob 明确说明 App Open Ad 有效期 4 小时
//     → ttl 在 AdUnit 中配置为 4 * 3600 秒

import Foundation
import UIKit
import GoogleMobileAds

public final class AdMobSplashAd: AdMobAds, FullScreenAd {

    public override var format: AdFormat { .ad_splash }

    private var appOpenAd: AppOpenAd?

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { cont in
            let request = Request()
            
            AppOpenAd.load(
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
                    self.appOpenAd = ad
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
        guard let ad = appOpenAd else { return false }
        ad.fullScreenContentDelegate = fullScreenCallbackWrapper
        ad.paidEventHandler = { [weak self] paidEvent in
            self?.fullScreenCallbackWrapper.onPaidEvent(paidEvent)
        }
        ad.present(from: viewController)
        return true
    }

    // MARK: - Cleanup

    public override func destroy() {
        Task{@MainActor in
            appOpenAd?.fullScreenContentDelegate = nil
            appOpenAd?.paidEventHandler = nil
            appOpenAd = nil
        }
    }

    public override func clearAdInstance() {
        appOpenAd = nil
    }

    public override func retrieveAd() -> Any? { appOpenAd }
}
