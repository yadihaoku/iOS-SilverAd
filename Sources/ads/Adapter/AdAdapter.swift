// AdAdapter.swift
// Translated from AdAdapter.kt

import UIKit

// MARK: - Ad Protocol (对应 Kotlin interface Ad)

public protocol Ad: AnyObject {
    var format: AdFormat { get }
    var providerName: String { get }
    var adUnit: AdUnit { get }

    /// 原始广告对象（SDK 返回的底层实例）
    var originAd: Any? { get }

    var uuid: String { get }

    /// 当前广告场景
    var currentAdScene: AdScene? { get set }

    /// 异步加载广告（Swift async/await 替代 Kotlin suspend）
    @MainActor
    func load() async -> Result<Bool, Error>

    func isReady() -> Bool
    func destroy()
    func setAdCallback(_ callback: InteractionCallback)
    func isExpired() -> Bool
    func expireTimestamp() -> TimeInterval
    func adLoadTime() -> TimeInterval
}

// MARK: - ViewAd Protocol (横幅 / Native 等可嵌入视图的广告)

@MainActor
public protocol ViewAd: Ad {
    func detach()
    func asView(options: ViewAdOptions?) -> UIView?
    func retrieveAdLoader() -> NSObject?
}

extension UIView {

    static func loadFromNib<T: UIView>(
        nibName: String,
        owner: Any? = nil
    ) -> T? {



        // Bundle.main 加载（闭源 SDK 场景，xib 被手动复制到主工程）
        if Bundle.main.path(forResource: nibName, ofType: "nib") != nil {
            return Bundle.main
                .loadNibNamed(nibName, owner: owner, options: nil)?
                .first as? T
        }
        
        // 从 Bundle.module 加载（SPM 库自身资源）
        if Bundle.module.path(forResource: nibName, ofType: "nib") != nil {
            return Bundle.module
                .loadNibNamed(nibName, owner: owner, options: nil)?
                .first as? T
        }
        return nil
    }
}

// MARK: - FullScreenAd Protocol (全屏广告：插屏、激励、开屏)

public protocol FullScreenAd: Ad {
    /// 展示广告，返回是否成功
    @discardableResult
    @MainActor
    func show(from viewController: UIViewController?) -> Bool
}

// MARK: - Callbacks

public protocol InteractionCallback: AnyObject {
    func onAdClicked()
    func onAdClosed()
    func onAdShowed()
    func onAdImpression()
    func onAdsPaid()
}

public protocol OnRewardCallback: AnyObject {
    func onReward()
}

/// 空实现适配器（对应 Kotlin open class AdCallbackAdapter）
open class AdCallbackAdapter: InteractionCallback {
    public init() {}
    open func onAdClicked() {}
    open func onAdClosed() {}
    open func onAdShowed() {}
    open func onAdImpression() {}
    open func onAdsPaid() {}
}

// MARK: - ViewAdOptions

/// 原生广告容器布局 ID（iOS 使用 xib 名称或 UIView 类型替代 @LayoutRes Int）
public struct NativeAdConfig {
    public let adMobContainerNibName: String
    public let maxAdContainerNibName: String

    public init(adMobContainerNibName: String, maxNativeAdNibName: String) {
        self.adMobContainerNibName = adMobContainerNibName
        self.maxAdContainerNibName = maxNativeAdNibName
    }
}
public protocol ViewAdOptions: AnyObject {
    var container: NativeAdConfig { get }
}



public final class ViewAdOptionsImpl: ViewAdOptions {
    public let container: NativeAdConfig
    
    public init(container: NativeAdConfig) {
        self.container = container
    }
    
    public convenience init(admobNib: String, maxNib: String) {
        self.init(
            container: NativeAdConfig(
                adMobContainerNibName: admobNib,
                maxNativeAdNibName: maxNib
            )
        )
    }
}
