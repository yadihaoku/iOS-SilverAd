// AdMobBannerAd.swift
// Translated from AdMobBannerAd.kt
//
// Swift 6 并发说明：
// - 整个类标注 @MainActor，AdManagerBannerView 要求主线程，@MainActor 天然满足
// - 替代 DispatchQueue.main.async { [weak self] } 的 @Sendable 写法
// - bannerLoadDelegate 用实例变量强持有，生命周期与 AdMobBannerAd 绑定

import Foundation
import UIKit
import GoogleMobileAds

@MainActor
public final class AdMobBannerAd: AdMobAds, ViewAd {

    

    public override var format: AdFormat { .ad_banner }

    // MARK: - Private State

    private var bannerView: AdManagerBannerView?
    private var bannerLoadDelegate: BannerLoadDelegate?
    private var adContainerView: AdBannerContainerView?
    
    public func retrieveAdLoader() -> NSObject? {
        return nil
    }

    // MARK: - Load

    public override func safeLoad() async throws -> Bool {
        // @MainActor 类的 async 方法天然在主线程执行，无需 DispatchQueue 包装
        return try await withCheckedThrowingContinuation { cont in

            let banner = AdManagerBannerView()
            banner.adUnitID = adUnit.adId

            let screenWidth = UIScreen.main.bounds.width
            banner.adSize = largeAnchoredAdaptiveBanner(width: screenWidth)
            SilverAdLog.d("AdMobBannerAd.safeLoad -> adWidth=\(screenWidth) (\(adUnit))")

            banner.paidEventHandler = { [weak self] paidEvent in
                guard let self else { return }
                self.updateEventData(with: paidEvent)
                SilverAdLog.w("AdMobBannerAd.onPaid value=\(paidEvent.value) currency=\(paidEvent.currencyCode)")
                self.delegate.onAdsPaid()
            }

            let loadDelegate = BannerLoadDelegate(
                onLoaded: { [weak self, weak banner] in
                    guard let self, let banner else { return }
                    self.updateEventData(with: banner.responseInfo)
                    self.markReady()
                    cont.resume(returning: true)
                },
                onFailed: { error in
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

            banner.delegate = loadDelegate

            // 实例变量强持有，ARC 管理生命周期
            self.bannerLoadDelegate = loadDelegate
            self.bannerView = banner

            banner.load(AdManagerRequest())
        }
    }

    // MARK: - ViewAd Protocol

    public func asView(options: ViewAdOptions?) -> UIView? {
        guard isReady(), let banner = bannerView else {
            detach()
            return nil
        }
        if adContainerView == nil {
            adContainerView = AdBannerContainerView(bannerView: banner)
        }
        SilverAdLog.w("AdMobBannerAd.asView isReady=\(isReady()) container=\(String(describing: adContainerView))")
        return adContainerView
    }

    public func detach() {
        adContainerView?.removeFromSuperview()
    }

    // MARK: - Cleanup

    public override func destroy() {
        Task{@MainActor in
            
            detach()
            bannerView?.delegate = nil
            bannerView?.paidEventHandler = nil
            bannerView?.removeFromSuperview()
            bannerView = nil
            bannerLoadDelegate = nil
            adContainerView = nil
        }
    }

    public override func clearAdInstance() {
        destroy()
    }

    public override func retrieveAd() -> Any? { bannerView }
}

// MARK: - BannerLoadDelegate

private class BannerLoadDelegate: NSObject, BannerViewDelegate {

    private let onLoaded: () -> Void
    private let onFailed: (Error) -> Void
    private let onClicked: () -> Void
    private let onClosed: () -> Void
    private let onImpression: () -> Void

    init(
        onLoaded: @escaping () -> Void,
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

    func bannerViewDidReceiveAd(_ bannerView: BannerView)                              { onLoaded() }
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) { onFailed(error) }
    func bannerViewDidRecordClick(_ bannerView: BannerView)                            { onClicked() }
    func bannerViewDidDismissScreen(_ bannerView: BannerView)                          { onClosed() }
    func bannerViewDidRecordImpression(_ bannerView: BannerView)                       { onImpression() }
}

// MARK: - AdBannerContainerView

public class AdBannerContainerView: UIView, AdLifecycleManageable {

    private weak var banner: AdManagerBannerView?

    init(bannerView: AdManagerBannerView) {
        self.banner = bannerView
        super.init(frame: bannerView.bounds)
        addSubview(bannerView)

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            bannerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    public func resumeAd() { }
    public func pauseAd()  { }
    public func destroyAd() {
        banner?.delegate = nil
        banner?.removeFromSuperview()
        removeFromSuperview()
    }
}
