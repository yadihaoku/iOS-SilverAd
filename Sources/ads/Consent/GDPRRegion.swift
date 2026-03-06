//
//  GDPRRegion.swift
//  SilverAd
//
//  Created by yyd on 6/3/2026.
//


import Foundation
import CoreTelephony

public enum GDPRRegion {

    // EEA + 英国（GDPR 适用区域）
    private static let gdprCountryCodes: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE",
        "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV",
        "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
        "SI", "ES", "SE", "GB"
    ]

    /// 判断给定国家码是否在 GDPR 区域内
    public static func isGDPRRegion(_ countryCode: String) -> Bool {
        gdprCountryCodes.contains(countryCode.uppercased())
    }

    /// 根据设备当前区域设置自动判断
    public static func isCurrentRegionGDPR() -> Bool {
        // 通用方案：用系统 Locale
        let code = Locale.current.region?.identifier
        ?? Locale.current.region?.identifier   // iOS 16 以下 fallback
                ?? ""
        
        debugPrint("regionCode: \(code)")
        // code 为空
        // 认为在 EEA  区域
        if code.isEmpty{
            return true
        }
        
        return isGDPRRegion(code)
    }

    /// 结合 MAX SDK 返回的 countryCode 判断（在 SDK 初始化回调中使用）
    public static func isGDPRRegion(sdkCountryCode: String) -> Bool {
        isGDPRRegion(sdkCountryCode)
    }
}
