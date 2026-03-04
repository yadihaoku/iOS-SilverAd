// MaxProvider.swift
// AppLovin MAX AdProvider 实现 + SDK 初始化入口
//
// 对应关系：
//   AdMobProvider   →  MaxProvider
//   AdMobAds.kt 中的 AdMobFullScreenCallbackWrapper  →  MaxAds.swift 中的 MaxFullScreenCallbackWrapper
//
// MAAdInfo 说明：
//   MAX revenue 回调通过 MAAdRevenueDelegate.didPayRevenue(for ad: MAAd) 传入 MAAd
//   MAAd.revenue        = 单次展示收益（美元）
//   MAAd.networkName    = 广告网络名称（如 "ADMOB_NETWORK", "FACEBOOK", "APPLOVIN"）
//   MAAd.adUnitIdentifier = MAX 代码位 ID

import Foundation
import UIKit
import AppLovinSDK

// MARK: - MaxProvider（对应 AdMobProvider / TopOnProvider）


