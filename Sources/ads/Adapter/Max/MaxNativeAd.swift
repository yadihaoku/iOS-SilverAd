// MaxNativeAd.swift
// AppLovin MAX Native 广告
//
// MAX API 对应：
//   GADAdLoader           →  MANativeAdLoader
//   GADNativeAdDelegate   →  MANativeAdDelegate
//   NativeAdView          →  MANativeAdView（手动绑定 outlet）
//   nativeAdView.nativeAd →  loader.register(nativeAdView:)
//
// MAX Native 绑定流程：
//   1. MANativeAdLoader.loadAd() 加载
//   2. 在 didLoadNativeAd 中收到 MAAd + MANativeAd
//   3. 创建 MANativeAdView（从 xib 或 code）
//   4. 调用 loader.register(nativeAdView:withContainerView:) 完成注册
//   5. 手动填充 titleLabel / bodyLabel / callToActionButton / iconImageView / mediaView
//   清理时调用 loader.destroy(ad:) 释放

import Foundation
import UIKit
import AppLovinSDK

public final class MaxNativeAd: MaxAds, ViewAd {
    
    public override var format: AdFormat { .ad_native }
    
    private var adLoader: MANativeAdLoader?
    private var loadedAd: MAAd?
    private var nativeAd: MANativeAd?
    private var nativeAdView: MANativeAdView?
    private var loadContinuation: CheckedContinuation<Bool, Error>?
    
    public func retrieveAdLoader() -> NSObject? {
        return adLoader
    }
    
    // MARK: - Load
    
    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else {
                cont.resume(throwing: AdLoadException(code: AdLoadException.CODE_SDK_ERROR, msg: "self released"))
                return
            }
            self.loadContinuation = cont
            
            let loader = MANativeAdLoader(adUnitIdentifier: adUnit.adId)
            loader.nativeAdDelegate = self
            loader.revenueDelegate = self
            self.adLoader = loader
            loader.loadAd()
            
        }
    }
    
    // MARK: - ViewAd Protocol
    
    public func asView(options: ViewAdOptions?) -> UIView? {
        guard isReady(), let nativeAd, let loadedAd else {
            detach()
            return nil
        }
        
        // 若已有 view 直接复用
        if let existing = nativeAdView { return existing }
        
        // 从 xib 加载或 fallback code 布局
        let nibName = options?.container.maxAdContainerNibName ?? SilverAd.DEFAULT_MAX_NATIVE_AD_CONTAINER
        let adView = createNativeAdView(nibName)
        
        // 绑定数据（对应 AdMob 的 populate(adView:with:)）
        populate(adView: adView, with: loadedAd)
        
        
        self.nativeAdView = adView
        
        SilverAdLog.w("MaxNativeAd.asView: bound nativeAdView (\(adUnit))")
        return adView
    }
    
    public func detach() {
        nativeAdView?.removeFromSuperview()
    }
    
    // MARK: - Cleanup
    public override func destroy() {
        Task{@MainActor in
            detach()
            // MAX 要求调用 destroy 释放 native ad 资源
            if let ad = loadedAd {
                adLoader?.destroy(ad)
            }
            adLoader?.nativeAdDelegate = nil
            adLoader?.revenueDelegate = nil
            adLoader = nil
            loadedAd = nil
            nativeAd = nil
            nativeAdView = nil
            loadContinuation = nil
        }
    }
    
    public override func clearAdInstance() {
        destroy()
    }
    
    public override func retrieveAd() -> Any? { nativeAd }
    
    
    func createNativeAdView(_ nibName : String) -> MANativeAdView
    {
        let nativeAdViewNib = UINib(nibName: nibName, bundle: Bundle.main)
        let nativeAdView = nativeAdViewNib.instantiate(withOwner: nil, options: nil).first! as! MANativeAdView
        
        let adViewBinder = MANativeAdViewBinder(builderBlock: { builder in
            builder.titleLabelTag = 1001
            builder.advertiserLabelTag = 1002
            builder.bodyLabelTag = 1003
            builder.iconImageViewTag = 1004
            builder.optionsContentViewTag = 1005
            builder.mediaContentViewTag = 1006
            builder.callToActionButtonTag = 1007
            builder.starRatingContentViewTag = 1008
        })
        nativeAdView.bindViews(with: adViewBinder)
        
        return nativeAdView
    }
    
    
    private func populate(adView: MANativeAdView, with maad: MAAd) {
        adLoader?.renderNativeAdView(adView, with: maad)
    }
}

// MARK: - MANativeAdDelegate

extension MaxNativeAd: MANativeAdDelegate {

    public func didLoadNativeAd(_ nativeAdView: MANativeAdView?, for ad: MAAd) {
        SilverAdLog.d("MaxNativeAd: didLoadNativeAd (\(adUnit))")
        self.loadedAd = ad
        self.nativeAd = ad.nativeAd
        markReady()
    
        updateEventData(with: ad)
        loadContinuation?.resume(returning: true)
        loadContinuation = nil
    }

    public func didFailToLoadNativeAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        SilverAdLog.d("MaxNativeAd: didFailToLoad [\(error.code.rawValue)] \(error.message)")
        loadContinuation?.resume(throwing: AdLoadException(
            code: AdLoadException.CODE_SDK_ERROR,
            msg: "[\(error.code.rawValue)] \(error.message)"
        ))
        loadContinuation = nil
    }

    public func didClickNativeAd(_ ad: MAAd) {
        delegate.onAdClicked()
    }
}

// MARK: - MAAdRevenueDelegate

extension MaxNativeAd: MAAdRevenueDelegate {
    public func didPayRevenue(for ad: MAAd) {
        updateEventData(with: ad)
        delegate.onAdsPaid()
    }
}
