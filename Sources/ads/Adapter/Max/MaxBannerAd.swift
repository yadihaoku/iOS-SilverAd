// MaxBannerAd.swift
// AppLovin MAX Banner 广告
//
// MAX API 对应：
//   AdManagerBannerView   →  MAAdView
//   adSize                →  MAAdFormat.banner / .leader / .mrec（由屏幕宽度决定）
//   BannerViewDelegate    →  MAAdViewAdDelegate
//   paidEventHandler      →  MAAdRevenueDelegate
//
// 注意：MAX Banner 用 MAAdView，自带自动刷新，destroy 前需调用 stopAutoRefresh()

import Foundation
import UIKit
import AppLovinSDK

public final class MaxBannerAd: MaxAds, ViewAd {

    public override var format: AdFormat { .ad_banner }

    private var adView: MAAdView?
    private var adContainerView: MaxBannerContainerView?
    private var loadContinuation: CheckedContinuation<Bool, Error>?

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        return try await withCheckedThrowingContinuation { [weak self] cont in
            guard let self else {
                cont.resume(throwing: AdLoadException(code: AdLoadException.CODE_SDK_ERROR, msg: "self released"))
                return
            }
            self.loadContinuation = cont

            // 根据屏幕宽度选择 Banner 尺寸（对应 AdMob 的 adaptive banner）
            let adFormat = MAAdView.adFormat(for: UIScreen.main.bounds.width)
            SilverAdLog.d("MaxBannerAd.safeLoad adFormat=\(adFormat.label) (\(adUnit))")

            let view = MAAdView(adUnitIdentifier: adUnit.adId, adFormat: adFormat)
            view.delegate = self
            view.revenueDelegate = self
            // 设置 frame：高度由 MAX SDK 推荐高度决定
            view.frame = CGRect(
                x: 0, y: 0,
                width: UIScreen.main.bounds.width,
                height: adFormat.size.height
            )
            self.adView = view
            view.loadAd()
        }
    }

    public func retrieveAdLoader() -> NSObject? {
        return nil
    }
    // MARK: - ViewAd Protocol

    public func asView(options: ViewAdOptions?) -> UIView? {
        guard isReady(), let adView else {
            detach()
            return nil
        }
        if adContainerView == nil {
            adContainerView = MaxBannerContainerView(adView: adView)
        }
        SilverAdLog.w("MaxBannerAd.asView isReady=\(isReady())")
        return adContainerView
    }

    public func detach() {
        adContainerView?.removeFromSuperview()
    }

    // MARK: - Cleanup

    public override func destroy() {
        Task{@MainActor in
            detach()
            adView?.stopAutoRefresh()
            adView?.delegate = nil
            adView?.revenueDelegate = nil
            adView?.removeFromSuperview()
            adView = nil
            adContainerView = nil
            loadContinuation = nil
        }
    }

    public override func clearAdInstance() {
        destroy()
    }

    public override func retrieveAd() -> Any? { adView }
}

// MARK: - MAAdViewAdDelegate

extension MaxBannerAd: MAAdViewAdDelegate {
    public func didFail(toDisplay ad: MAAd, withError error: MAError) {
        delegate.onAdFailedToShow()
    }
    

    public func didLoad(_ ad: MAAd) {
        markReady()
        updateEventData(with: ad)
        
        SilverAdLog.d("MaxBannerAd: didLoad (\(adUnit))")
        loadContinuation?.resume(returning: true)
        loadContinuation = nil
    }

    public func didFailToLoadAd(forAdUnitIdentifier adUnitIdentifier: String, withError error: MAError) {
        SilverAdLog.d("MaxBannerAd: didFailToLoad [\(error.code.rawValue)] \(error.message)")
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

    public func didHide(_ ad: MAAd) {
        delegate.onAdClosed()
    }

    public func didClick(_ ad: MAAd) {
        delegate.onAdClicked()
    }

    public func didExpand(_ ad: MAAd) { }
    public func didCollapse(_ ad: MAAd) { }
}

// MARK: - MAAdRevenueDelegate

extension MaxBannerAd: MAAdRevenueDelegate {
    public func didPayRevenue(for ad: MAAd) {
        updateEventData(with: ad)
        delegate.onAdsPaid()
    }
}

// MARK: - MAAdView 尺寸选择辅助

private extension MAAdView {
    /// 根据屏幕宽度选择合适的 Banner 格式（对应 AdMob currentOrientationAnchoredAdaptiveBannerAdSize）
    static func adFormat(for screenWidth: CGFloat) -> MAAdFormat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return screenWidth >= 728 ? .leader : .banner
        }
        return .banner
    }
}

// MARK: - MaxBannerContainerView（对应 AdBannerContainerView）

public class MaxBannerContainerView: UIView, AdLifecycleManageable {

    private weak var adView: MAAdView?

    init(adView: MAAdView) {
        self.adView = adView
        super.init(frame: adView.bounds)
        addSubview(adView)

        adView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: topAnchor),
            adView.bottomAnchor.constraint(equalTo: bottomAnchor),
            adView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public func resumeAd() { adView?.startAutoRefresh() }
    public func pauseAd()  { adView?.stopAutoRefresh() }
    public func destroyAd() {
        adView?.stopAutoRefresh()
        adView?.delegate = nil
        adView?.removeFromSuperview()
        removeFromSuperview()
    }
}
