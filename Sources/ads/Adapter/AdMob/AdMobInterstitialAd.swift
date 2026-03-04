// AdMobInterstitialAd.swift
// Translated from AdMobInterstitialAd.kt
//
// 翻译说明：
// - InterstitialAd.load(callback)  →  InterstitialAd.load(withAdUnitID:request:completionHandler:)
// - suspendCancellableCoroutine    →  async/await + withCheckedThrowingContinuation
// - activity: Activity             →  viewController: UIViewController
// - ad.show(activity)              →  ad.present(fromRootViewController:)

import Foundation
import UIKit
import GoogleMobileAds

public final class AdMobInterstitialAd: AdMobAds, FullScreenAd {
    
    public override var format: AdFormat { .ad_interstitial }
    
    private var interstitial: InterstitialAd?
    
    // MARK: - Load
    
    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { cont in
            let request = Request()
            InterstitialAd.load(
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
                    self.interstitial = ad
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
        guard let ad = interstitial else { return false }
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
            interstitial?.fullScreenContentDelegate = nil
            interstitial?.paidEventHandler = nil
            interstitial = nil
        }
    }
    
    public override func clearAdInstance() {
        interstitial = nil
    }
    
    public override func retrieveAd() -> Any? { interstitial }
}
