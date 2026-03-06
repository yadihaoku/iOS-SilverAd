// AdMobNativeAd.swift
// Translated from AdMobNativeAd.kt
//
// Swift 6 并发说明：
// - 整个类标注 @MainActor，所有属性访问和方法调用都在主线程
// - 替代 DispatchQueue.main.async + [weak self] 的 @Sendable 闭包写法
// - AdLoader 要求主线程创建，@MainActor 刚好满足这个要求
// - 去掉 NSLock（@MainActor 已保证单线程访问，锁不再需要）

import Foundation
import UIKit
import GoogleMobileAds

public final class AdMobNativeAd: AdMobAds, ViewAd {

    public override var format: AdFormat { .ad_native }

    // MARK: - Private State
    // 所有属性都在 @MainActor 保护下，无需额外加锁
    private var nativeAd: NativeAd?
    private var nativeAdView: NativeAdView?
    // adLoader 和 loaderDelegate 必须同时强持有：
    //   - adLoader：防止请求发出后 loader 被提前释放导致回调丢失
    //   - loaderDelegate：AdLoader.delegate 是 weak，必须有强引用方
    private var adLoader: AdLoader?
    private var loaderDelegate: NativeAdLoaderDelegate?

    public func retrieveAdLoader() -> NSObject? {
        return adLoader
    }

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        // @MainActor 类的 async 方法天然在主线程执行
        // 不需要 DispatchQueue.main.async 包装，直接写逻辑即可
        return try await withCheckedThrowingContinuation { cont in

            let adViewOptions = NativeAdViewAdOptions()
            adViewOptions.preferredAdChoicesPosition = .topRightCorner

            let loader = AdLoader(
                adUnitID: adUnit.adId,
                rootViewController: nil,
                adTypes: [.native],
                options: [adViewOptions]
            )

            let delegate = MixedNativeAdLoaderDelegate(
                onLoaded: { [weak self] nativeAd in
                    guard let self else { return }
                    self.nativeAd = nativeAd
                    self.updateEventData(with: nativeAd.responseInfo)
                    nativeAd.paidEventHandler = { [weak self] paidEvent in
                        self?.updateEventData(with: paidEvent)
                        self?.delegate.onAdsPaid()
                    }
                    self.markReady()
                    // 加载完成，loader 使命结束，释放强引用
                    self.adLoader = nil
                    cont.resume(returning: true)
                },
                onFailed: { [weak self] error in
                    self?.adLoader = nil
                    cont.resume(throwing: AdLoadException(
                        code: AdLoadException.CODE_SDK_ERROR,
                        msg: error.localizedDescription
                    ))
                },
                onClicked:    { [weak self] in self?.delegate.onAdClicked() },
                onClosed:     { [weak self] in self?.delegate.onAdClosed() },
                onImpression: { [weak self] in
                    self?.delegate.onAdShowed()
                    self?.delegate.onAdImpression()
                }
            )

            loader.delegate = delegate
            self.adLoader = loader
            self.loaderDelegate = delegate

            loader.load(Request())
        }
    }

    // MARK: - ViewAd Protocol

    public func asView(options: ViewAdOptions?) -> UIView? {
        // @MainActor 保证主线程，不需要 viewLock
        SilverAdLog.w("AdMobNativeAd.asView uuid=\(uuid) isReady=\(isReady()) nativeAdView=\(String(describing: nativeAdView))")

        guard isReady(),let ad = nativeAd else {
            detach()
            return nil
        }

        if nativeAdView == nil {
            let nibName = options?.container.adMobContainerNibName ?? SilverAd.DEFAULT_ADMOB_NATIVE_AD_CONTAINER
            if let adView = loadNativeAdView(nibName: nibName){
                populate(adView, with: ad)
                nativeAdView = adView
            }
        }
        return nativeAdView
    }

    public func detach() {
        nativeAdView?.removeFromSuperview()
    }

    // MARK: - Cleanup
    public override func destroy() {
        
        Task{@MainActor in
            detach()
            adLoader?.delegate = nil
            adLoader = nil
            loaderDelegate = nil
            nativeAdView?.nativeAd = nil  // 1. 先解除 NativeAdView 与 NativeAd 的关联
            nativeAdView = nil             // 2. 再释放视图
            self.nativeAd = nil
        }
        

    }

    public override func clearAdInstance() {
        destroy()
    }

    public override func retrieveAd() -> Any? { nativeAd }

    // MARK: - Private Helpers

    private func loadNativeAdView(nibName: String) -> NativeAdView? {
        let view : NativeAdView? = UIView.loadFromNib(nibName: nibName, owner: nil)
        return view
    }

    private func populate(_ nativeAdView: NativeAdView, with nativeAd: NativeAd) {

      // Each UI property is configurable using your native ad.
      (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline

      nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

      (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body

      (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image

      (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(from: nativeAd.starRating)

      (nativeAdView.storeView as? UILabel)?.text = nativeAd.store

      (nativeAdView.priceView as? UILabel)?.text = nativeAd.price

      (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser

      (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)

      // For the SDK to process touch events properly, user interaction should be disabled.
      nativeAdView.callToActionView?.isUserInteractionEnabled = false

      // Associate the native ad view with the native ad object. This is required to make the ad
      // clickable.
      // Note: this should always be done after populating the ad views.
      nativeAdView.nativeAd = nativeAd
    }
    
    private func imageOfStars(from starRating: NSDecimalNumber?) -> UIImage? {
      guard let rating = starRating?.doubleValue else {
        return nil
      }
      if rating >= 5 {
        return UIImage(named: "stars_5")
      } else if rating >= 4.5 {
        return UIImage(named: "stars_4_5")
      } else if rating >= 4 {
        return UIImage(named: "stars_4")
      } else if rating >= 3.5 {
        return UIImage(named: "stars_3_5")
      } else {
        return nil
      }
    }
}

// MARK: - NativeAdLoaderDelegate

private class MixedNativeAdLoaderDelegate: NSObject, NativeAdLoaderDelegate {

    private let onLoaded: (NativeAd) -> Void
    private let onFailed: (Error) -> Void
    private let onClicked: () -> Void
    private let onClosed: () -> Void
    private let onImpression: () -> Void

    init(
        onLoaded: @escaping (NativeAd) -> Void,
        onFailed: @escaping (Error) -> Void,
        onClicked: @escaping () -> Void,
        onClosed: @escaping () -> Void,
        onImpression: @escaping () -> Void
    ) {
        self.onLoaded     = onLoaded
        self.onFailed     = onFailed
        self.onClicked    = onClicked
        self.onClosed     = onClosed
        self.onImpression = onImpression
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAd.delegate = self
        onLoaded(nativeAd)
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        onFailed(error)
    }
}

extension MixedNativeAdLoaderDelegate: NativeAdDelegate {
    func nativeAdDidRecordClick(_ nativeAd: NativeAd)      { onClicked() }
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd)    { onClosed() }
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) { onImpression() }
}
