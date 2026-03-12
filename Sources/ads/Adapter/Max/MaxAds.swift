// MaxAds.swift
// AppLovin MAX 所有广告类型的基类
//
// 对应关系（与 AdMobAds 平行）：
//   AdMobAds             →  MaxAds
//   AdMobProvider        →  MaxProvider
//   FullScreenContentDelegate  →  MAAdDelegate / MARewardedAdDelegate
//   paidEventHandler     →  MAAdRevenueDelegate
//   BannerViewDelegate   →  MAAdViewAdDelegate
//   NativeAdLoaderDelegate → MANativeAdDelegate
//
// AppLovin MAX SDK 回调机制与 AdMob 的主要差异：
//   - AdMob 用 protocol delegate；MAX 统一用 delegate protocol（MAAdDelegate 等）
//   - AdMob paidEventHandler 是 closure；MAX 用独立的 MAAdRevenueDelegate protocol
//   - AdMob ResponseInfo 含 adNetworkClassName；MAX 用 MAAdInfo.networkName
//   - MAX 没有 RequestInfo，加载时直接传 adUnitIdentifier

import Foundation
import UIKit
import AppLovinSDK
import GoogleMobileAds

// MARK: - SilverAd Platform 常量扩展

public extension SilverAd {
    static let PLATFORM_MAX = "max"
    
    static let DEFAULT_MAX_NATIVE_AD_CONTAINER = "MaxAd_Large_Native"
}

// MARK: - MaxAds（所有 MAX 广告类型的基类）

open class MaxAds: BaseAd {
    
    public init(adUnit: AdUnit) {
        super.init(adUnit: adUnit, providerName_: SilverAd.PLATFORM_MAX)
    }
    
    /// 子类在广告展示完成 / 加载失败时调用（对应 AdMobAds.clearAdInstance）
    open func clearAdInstance() {
        fatalError("Subclass must override clearAdInstance()")
    }
    
    // MARK: - 更新 Revenue 数据（对应 AdMobAds.updateEventDataWith(AdValue)）
    //
    // MAX 通过 MAAdRevenueDelegate 回调 MAAdInfo，而非 closure 方式
    
    // Revenue 上报见 MaxProvider.swift 的 MaxAds extension
}


// MARK: - MAAdInfo 扩展（revenue 数据桥接）
//
// MAX 通过 MAAd 暴露收益数据，封装为统一 updateEventData 接口

extension MaxAds {
    /// 从 MAAd 直接提取 revenue 数据，避免 MAAdInfo 初始化问题
    func updateEventData(with ad: MAAd) {
        updateEvent { data in
            data.currencyCode = "USD"
            data.revenuePrecision = convertRevenuePrecision(revenePrecesion: ad.revenuePrecision)
            data.micros       = Int64(ad.revenue * 1_000_000)
            data.adSourceName = ad.networkName.lowercased()
            data.thirdPartyAdPlacementId = ad.networkPlacement
        }
    }
    
    /**
     * The precision of the revenue value for this ad.
     *
     * Possible values are:
     * - "publisher_defined" - If the revenue is the price assigned to the line item by the publisher.
     * - "exact" - If the revenue is the resulting price of a real-time auction.
     * - "estimated" - If the revenue is the price obtained by auto-CPM.
     * - "undefined" - If we do not have permission from the ad network to share impression-level data.
     * - "" - An empty string, if revenue and precision are not valid (for example, in test mode).
     */
    private func convertRevenuePrecision(revenePrecesion : String) -> Int{
        switch(revenePrecesion){
        case "publisher_defined":
            return AdValuePrecision.publisherProvided.rawValue
        case "estimated":
            return AdValuePrecision.estimated.rawValue
        case "exact":
            return AdValuePrecision.precise.rawValue
        default:
            return AdValuePrecision.unknown.rawValue
        }
    }
}


