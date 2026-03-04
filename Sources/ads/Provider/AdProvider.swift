// AdProvider.swift
// Translated from AdProvider.kt / AdMobProvider.kt / TopOnProvider.kt

import Foundation

// MARK: - AdProvider Protocol

public protocol AdProvider: AnyObject {
    var name: String { get }
    @MainActor
    func createAd(adUnit: AdUnit) async -> any Ad
}

// MARK: - AdMobProvider

public class AdMobProvider: AdProvider {
    public let name: String = SilverAd.PLATFORM_ADMOB
    
    public init() {}
    
    public func createAd(adUnit: AdUnit) async -> any Ad {
        switch adUnit.type {
        case .ad_interstitial:
            return AdMobInterstitialAd(adUnit: adUnit)
        case .ad_splash:
            return AdMobSplashAd(adUnit: adUnit)
        case .ad_reward:
            return AdMobRewardAd(adUnit: adUnit)
        case .ad_reward_interstitial:
            return AdMobRewardInterstitialAd(adUnit: adUnit)
        case .ad_banner:
            return AdMobBannerAd(adUnit: adUnit)
        case .ad_native:
            return AdMobNativeAd(adUnit: adUnit)
        }
    }
}


public final class MaxProvider: AdProvider {
    
    public let name: String = SilverAd.PLATFORM_MAX
    
    public init() {}
    
    public func createAd(adUnit: AdUnit) -> any Ad {
        switch adUnit.type {
        case .ad_interstitial:     return MaxInterstitialAd(adUnit: adUnit)
        case .ad_splash:           return MaxSplashAd(adUnit: adUnit)
        case .ad_banner:           return MaxBannerAd(adUnit: adUnit)
        case .ad_native:          return MaxNativeAd(adUnit: adUnit)
        case .ad_reward_interstitial,.ad_reward:           return MaxRewardAd(adUnit: adUnit)
        }
    }
}
