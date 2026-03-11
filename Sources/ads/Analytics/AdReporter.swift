// AdReporter.swift
// Translated from AdReporter.kt
//
// 翻译说明：
// - Kotlin interface AdReporter          →  Swift protocol AdReporter
// - Kotlin object SilverAdEvent          →  Swift enum SilverAdEvent（无实例，纯命名空间）
// - Kotlin enum class AdShowFailReason   →  Swift enum AdShowFailReason: String
// - Kotlin data class EventData          →  Swift struct EventData（值类型更合适）
// - Android ResponseInfo                 →  Swift 中替换为 ResponseInfo（GMA SDK v12 类型）
// - Kotlin companion object / val get()  →  Swift static let

import Foundation
import GoogleMobileAds

// MARK: - AdReporter Protocol

public protocol AdReporter: AnyObject {
    func reportEvent(event: String, eventData: EventData?, extras: [String: Any]?)
}

// MARK: - SilverAdEvent（对应 Kotlin object SilverAdEvent）

public enum SilverAdEvent {
    public static let adImpression    = "st_ad_impression"
    public static let adPaid          = "st_ad_paid"
    public static let adClick         = "st_ad_click"
    public static let adClose         = "st_ad_close"
    public static let adLoadResult    = "st_ad_load_result"
    public static let adFetchResult   = "st_ad_fetch_result"
    public static let adShowCheck     = "st_ad_show_check_result"
    public static let adConfigUpdate  = "st_ad_config_update"
    public static let initFailure     = "st_ad_init_failure"

    // 对应 Kotlin object Param
    public enum Param {
        public static let result        = "result"
        public static let scene         = "scene"
        public static let pageName      = "page_name"
        public static let reason        = "reason"
        public static let consumeTime   = "consume_time"
        public static let from          = "from"
        public static let msg           = "msg"
        public static let configVersion = "config_version"
        public static let hasTimeOut    = "has_time_out"
        public static let newVersion    = "new_version"
        public static let oldVersion    = "old_version"
    }
}

// MARK: - AdShowFailReason（对应 Kotlin enum class AdShowFailReason）

public enum AdShowFailReason: String {
    case clickLimit         = "click_limit"
    case showLimit          = "show_limit"
    case singleAdClickLimit = "single_ad_click_limit"
    
    case intervalShowLimit  = "interval_show_limit"
    case intervalDuration   = "interval_duration"
    case sceneNotMatch      = "scene_not_match"
    case adUnitNotFound     = "ad_unit_not_found"
    case blockByInterceptor = "block_by_interceptor"
    case networkError       = "network_error"
    case other              = "other"
    case none              = ""
}

// MARK: - EventData（对应 Kotlin data class EventData）
//
// 用 struct 而非 class：
//   - Kotlin data class 是值语义（copy 时独立）
//   - Swift struct 同样是值类型，每次赋值/传参都是独立副本
//   - 与 BaseAd 里 buildEventData() 调用 copy() 的语义完全对应

public struct EventData {
    public var scene: String?
    public var adUnit: AdUnit?
    public var thirdPartyAdPlacementId: String?
    public var currencyCode: String = "USD"
    /// 对应 Kotlin micros: Long（单位：微分）
    public var micros: Int64 = -1
    /// 对应 Kotlin revenuePrecision: Int?（AdValue.PrecisionType 的原始值）
    public var revenuePrecision: Int?
    public var extras: [String: Any] = [:]
    public var adSourceName: String?
    public var consumeTime: Int64?
    /// 对应 Kotlin admobResponse: ResponseInfo?（GMA SDK v12）
    public var responseInfo: ResponseInfo?

    public init(
        scene: String?,
        adUnit: AdUnit? = nil,
        thirdPartyAdPlacementId: String? = nil,
        currencyCode: String = "USD",
        micros: Int64 = -1,
        revenuePrecision: Int? = nil,
        extras: [String: Any] = [:]
    ) {
        self.scene = scene
        self.adUnit = adUnit
        self.thirdPartyAdPlacementId = thirdPartyAdPlacementId
        self.currencyCode = currencyCode
        self.micros = micros
        self.revenuePrecision = revenuePrecision
        self.extras = extras
    }
}

public extension EventData {

    func toMap() -> [String: Any] {
        var map: [String: Any] = [
            "scene":                  scene ?? "",
            "thirdPartyAdPlacementId": thirdPartyAdPlacementId ?? "",
            "ad_currency":            currencyCode,
            "usd_micro":              micros,
            "precision_type":         revenuePrecision ?? AdValuePrecision.unknown.rawValue,
            "media_source_name":      adSourceName ?? "",
            "consume_time":           consumeTime ?? -1,
        ]

        // 合并 adUnit 字段（对应 Kotlin adUnit?.toMap()?.let { putAll(it) }）
        if let unitMap = adUnit?.toMap() {
            map.merge(unitMap) { _, new in new }
        }

        // 合并 extras（对应 Kotlin putAll(extras)）
        map.merge(extras) { _, new in new }

        return map
    }
}

// MARK: - AdUnit.toMap()（对应 Kotlin fun AdUnit.toMap()）

public extension AdUnit {

    func toMap() -> [String: Any] {
        return [
            "platform_ad_unit":       adId,
            "unit_name":     name,
            "ad_platform": platform,
            "ad_type":     type.rawValue,
            "ecpm":     ecpm,
            "auto_fill": autoFill
        ]
    }
}
