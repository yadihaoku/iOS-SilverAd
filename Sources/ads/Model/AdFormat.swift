// AdFormat.swift
// Translated from AdType.kt

/// 广告格式枚举
/// - 注意各格式有效期：
///   - banner/native: 最长1小时（建议不缓存，直接加载）
///   - interstitial/reward: 1小时
///   - splash: 4小时（AdMob 明确说明）
public enum AdFormat: String, Codable, CaseIterable {
    case ad_banner              = "banner"
    case ad_native              = "native"      // Swift 中 native 是保留关键字，用 native_ 代替
    case ad_interstitial        = "interstitial"
    case ad_reward              = "reward"
    case ad_reward_interstitial = "reward_interstitial"
    case ad_splash              = "appopen"
}
