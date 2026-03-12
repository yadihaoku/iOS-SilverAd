// AdMobAds.swift
// Translated from AdMobAds.kt
//
// 翻译说明：
// - Kotlin abstract class AdMobAds : BaseAd  →  open class AdMobAds: BaseAd
// - Kotlin inner class AdMobFullScreenCallbackWrapper
//     → Swift nested class，持有 weak parent 引用
// - FullScreenContentCallback + OnPaidEventListener + OnUserEarnedRewardListener
//     → 合并成一个 Swift class，分别实现 FullScreenContentDelegate、PaidEventHandler
// - AdListener (Banner/Native 用)
//     → BannerViewDelegate / NativeAdLoaderDelegate
// - AdMobViewWrapper (ILifecycleAdView)
//     → AdMobBannerViewWrapper: AdLifecycleManageable

import Foundation
import GoogleMobileAds          // 需要在 Package.swift 中引入 Google Mobile Ads SPM

public extension SilverAd {
    static let PLATFORM_ADMOB = "admob"
    
    static let DEFAULT_ADMOB_NATIVE_AD_CONTAINER = "AdMobAd_Large_Native"
}

// MARK: - AdMobAds（所有 AdMob 广告类型的基类）
@MainActor
open class AdMobAds: BaseAd {

    public init(adUnit: AdUnit) {
        super.init(adUnit: adUnit, providerName_: SilverAd.PLATFORM_ADMOB)
    }

    /// 子类在广告实例失效时调用（展示完毕 / 加载失败）
    open func clearAdInstance() {
        fatalError("Subclass must override clearAdInstance()")
    }

    // MARK: - 更新付费事件数据（对应 updateEventDataWith(AdValue)）

    func updateEventData(with paidEvent: AdValue?) {
        guard let p1 = paidEvent else { return }
        
        updateEvent {
            $0.currencyCode = p1.currencyCode
            $0.revenuePrecision = p1.precision.rawValue
            $0.micros = Int64(truncating: p1.value)
        }
        // 此处可将 paid.value / paid.currencyCode 上报到 EventReporter
        // 保持与 Kotlin 一致的结构，留给上层集成
        SilverAdLog.w("AdMobAds: paidEvent value=\(p1.value) currency=\(p1.currencyCode) precision=\(p1.precision.rawValue)")
    }

    // MARK: - 更新响应信息（对应 updateEventDataWith(ResponseInfo)）

    func updateEventData(with responseInfo: ResponseInfo?) {
        guard let info = responseInfo else { return }
        
        
        updateEvent {
            let networkName = getNetworkName(from: info.loadedAdNetworkResponseInfo)
            $0.responseInfo = info
            $0.adSourceName = networkName
            
            SilverAdLog.d("AdMobAds: adSourceName=\(networkName ?? "unknown")")
        }
        
        
    }

    // MARK: - 解析广告网络名称（对应 Kotlin getNetworkName）

    private func getNetworkName(from adapterInfo: AdNetworkResponseInfo?) -> String? {
        guard let className = adapterInfo?.adNetworkClassName else { return nil }

        switch true {
        case className == "com.google.ads.mediation.admob.AdMobAdapter",
             className.hasPrefix("GADMAdapterGoogleAdMobAds"):
            return "admob"
        case className.hasPrefix("com.google.ads.mediation.facebook"),
             className.hasPrefix("GADMAdapterFacebook"):
            return "facebook"
        case className.hasPrefix("com.google.ads.mediation.applovin"),
             className.hasPrefix("GADMAdapterAppLovin"):
            return "applovin"
        case className.hasPrefix("com.google.ads.mediation.ironsource"),
             className.hasPrefix("GADMAdapterIronSource"):
            return "ironSource"
        case className.hasPrefix("com.google.ads.mediation.inmobi"),
             className.hasPrefix("GADMAdapterInMobi"):
            return "inmobi"
        case className.hasPrefix("com.google.ads.mediation.unity"),
             className.hasPrefix("GADMAdapterUnity"):
            return "unity"
        case className.hasPrefix("com.google.ads.mediation.vungle"),
             className.hasPrefix("GADMAdapterVungle"):
            return "vungle"
        case className.hasPrefix("com.google.ads.mediation.pangle"),
             className.hasPrefix("GADMAdapterPangle"):
            return "pangle"
        case className.hasPrefix("com.google.ads.mediation.mintegral"),
             className.hasPrefix("GADMAdapterMintegral"):
            return "mintegral"
        default:
            // 尝试从类名中提取网络名（对应 Kotlin 的 prefix 截取逻辑）
            let prefix = "com.google.ads.mediation."
            if className.hasPrefix(prefix) {
                let rest = String(className.dropFirst(prefix.count))
                return rest.components(separatedBy: ".").first
            }
            return className
        }
    }

    // MARK: - 全屏广告回调包装器（对应 Kotlin inner class AdMobFullScreenCallbackWrapper）
    //
    // iOS 对应关系：
    //   FullScreenContentCallback  → FullScreenContentDelegate
    //   OnPaidEventListener        → paidEventHandler (closure，iOS SDK 用 block)
    //   OnUserEarnedRewardListener → UserDidEarnRewardHandler (closure)

    public lazy var fullScreenCallbackWrapper = AdMobFullScreenCallbackWrapper(parent: self)

    public class AdMobFullScreenCallbackWrapper: NSObject, FullScreenContentDelegate {

        private weak var parent: AdMobAds?

        init(parent: AdMobAds) {
            self.parent = parent
        }

        // MARK: FullScreenContentDelegate

        /// 广告被关闭（对应 onAdDismissedFullScreenContent）
        public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
            parent?.delegate.onAdClosed()
            parent?.clearAdInstance()
        }

        /// 广告展示失败（对应 onAdFailedToShowFullScreenContent）
        public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
            parent?.clearAdInstance()
            parent?.delegate.onAdFailedToShow()
        }

        /// 广告开始展示（对应 onAdShowedFullScreenContent）
        public func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
            parent?.delegate.onAdShowed()
        }

        /// 广告被点击（对应 onAdClicked）
        public func adDidRecordClick(_ ad: FullScreenPresentingAd) {
            parent?.delegate.onAdClicked()
        }

        /// 广告曝光（对应 onAdImpression）
        public func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
            parent?.delegate.onAdImpression()
        }

        // MARK: Paid / Reward（iOS SDK 用 closure，在各广告类中设置）

        func onPaidEvent(_ paidEvent: AdValue) {
            Task{@MainActor in
                parent?.updateEventData(with: paidEvent)
                parent?.delegate.onAdsPaid()
            }
        }

        func onUserEarnedReward() {
            Task{@MainActor in
                parent?.delegate.onReward()
            }
            
        }
    }

    // MARK: - Banner / Native 视图广告加载监听（对应 Kotlin open inner class ViewAdLoadListenerImpl）
    //
    // iOS 对应：BannerViewDelegate（Banner）和 NativeAdLoaderDelegate（Native）
    // 两者逻辑类似，提取公共部分为 ViewAdListenerBase

    public class ViewAdListenerBase: NSObject {
        weak var parent: AdMobAds?
        init(parent: AdMobAds) { self.parent = parent }
    }
}

// MARK: - AdMobBannerViewWrapper（对应 Kotlin class AdMobViewWrapper : ILifecycleAdView）

public class AdMobBannerViewWrapper: AdLifecycleManageable {
    private weak var bannerView: AdManagerBannerView?

    public init(bannerView: AdManagerBannerView) {
        self.bannerView = bannerView
    }

    public func resumeAd() {
        // AdManagerBannerView 在 iOS 上通过 ViewController 生命周期自动管理
        // 如需手动控制，可在此调用 bannerView?.load() 刷新
    }

    public func pauseAd() {
        // iOS 无直接 pause API；可在此停止自动刷新（若有）
    }

    public func destroyAd() {
        bannerView?.removeFromSuperview()
    }
}

// MARK: - AdLifecycleManageable Protocol（对应 Kotlin interface ILifecycleAdView）

public protocol AdLifecycleManageable: AnyObject {
    func resumeAd()
    func pauseAd()
    func destroyAd()
}
