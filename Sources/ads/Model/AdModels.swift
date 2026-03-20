// AdModels.swift
// Translated from AdUnit.kt / AdPool.kt / AdScene.kt / AdConfig.kt

import Foundation

// MARK: - AdUnit

public struct AdUnit: Codable, Hashable {
    public var state: Int           // 1 启用，0 其它
    public var type: AdFormat
    public var adId: String         // 代码位 ID
    public var name: String
    public var platform: String     // "admob" | "topon"
    public var autoFill: TimeInterval  // -1 禁止自动填充；>= 0 为 delay 秒数（Kotlin 用毫秒，iOS 这里统一用秒）
    public var ttl: TimeInterval    // 广告有效期（秒）
    public var ecpm: Int

    public init(
        state: Int,
        type: AdFormat,
        adId: String,
        name: String,
        platform: String,
        autoFill: TimeInterval,
        ttl: TimeInterval,
        ecpm: Int = 0
    ) {
        self.state = state
        self.type = type
        self.adId = adId
        self.name = name
        self.platform = platform
        self.autoFill = autoFill
        self.ttl = ttl
        self.ecpm = ecpm
    }

    /// 是否启用自动填充（autoFill >= 0）
    public func autoRefill() -> Bool {
        return autoFill >= 0
    }

    public func desc() -> String {
        return "\(platform)|\(type.rawValue)|\(name)|\(adId)"
    }

    // MARK: Hashable / Equatable（只比较 adId + type，与 Kotlin 保持一致）
    public static func == (lhs: AdUnit, rhs: AdUnit) -> Bool {
        return lhs.adId == rhs.adId && lhs.type == rhs.type
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(adId)
        hasher.combine(type)
    }
}

// MARK: - AdPool

public struct AdPool: Codable {
    public var state: Int           // 1 启用，0 禁用
    public var type: AdFormat
    public var loadOnStart: Int     // 1 启动时加载
    public var name: String
    public var adUnits: [AdUnit]

    public init(state: Int, type: AdFormat, loadOnStart: Int, name: String, adUnits: [AdUnit]) {
        self.state = state
        self.type = type
        self.loadOnStart = loadOnStart
        self.name = name
        self.adUnits = adUnits
    }
}

// MARK: - AdScene

public struct AdScene {
    public let sceneName: String
    public let state: Int
    public let waitDuration: TimeInterval       // 毫秒
    public let adPools: [String]

    public func isEnabled() -> Bool {
        return state == 1
    }
}

// MARK: - AdSceneGroup（对应 Kotlin @Serializable data class AdSceneGroup）

public struct AdSceneGroup: Codable {
    public let sceneName: [String]
    public let state: Int
    public let waitDuration: TimeInterval
    public let adPools: [String]
    
    
   public init(sceneName: [String], state: Int, waitDuration: TimeInterval, adPools: [String]) {
       self.sceneName = sceneName
       self.state = state
       self.waitDuration = waitDuration
       self.adPools = adPools
   }
 
    /// 将 Group 展开为单个 AdScene
    public func asScene(_ name: String) -> AdScene {
        return AdScene(
            sceneName: name,
            state: state,
            waitDuration: waitDuration,
            adPools: adPools
        )
    }
}


// MARK: - AdPlatformConfig

/// 各广告平台的 SDK Key / App ID 配置
/// 目前包含 AppLovin MAX SDK Key，后续可按需扩展其它平台（如 AdMob App ID、Pangle App ID 等）
public struct AdPlatformConfig: Codable {
    /// AppLovin MAX SDK Key
    public let maxSdkKey: String?

    public init(maxSdkKey: String? = nil) {
        self.maxSdkKey = maxSdkKey
    }
}

// MARK: - AdConfig

public struct AdConfig: Codable {
    public let version: Int
    public let clickLimit: Int
    public let showLimit: Int
    public let state : Int
    public let adLimits : AdLimitConfig
    public let adPools: [AdPool]
    public let adScenes: [AdSceneGroup]
    /// 各广告平台的 Key / App ID 配置（可选，不存在时为 nil）
    public let platformConfig: AdPlatformConfig?

    // 懒加载 scenes Map（Swift 用 lazy var，但 struct 不支持 lazy；改为 computed + 内部缓存）
    // 用 class 包装或直接在 init 时构建
    public let scenes: [String: AdScene]
    public let pools: [String: AdPool]

    public init(version: Int, clickLimit: Int, showLimit: Int, state : Int = 1, adLimits : AdLimitConfig = .default, adPools: [AdPool], adScenes: [AdSceneGroup], platformConfig: AdPlatformConfig? = nil) {
        self.version = version
        self.clickLimit = clickLimit
        self.showLimit = showLimit
        self.adPools = adPools
        self.adScenes = adScenes
        self.adLimits = adLimits
        self.state = state
        self.platformConfig = platformConfig

        // 构建 scenes map
        var sceneMapping = [String: AdScene]()
        for group in adScenes {
            for name in group.sceneName {
                sceneMapping[name] = group.asScene(name)
            }
        }
        self.scenes = sceneMapping

        // 构建 pools map
        self.pools = Dictionary(uniqueKeysWithValues: adPools.map { ($0.name, $0) })
    }

    // Codable 自定义 init（从 JSON 解析后重建 computed maps）
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        let clickLimit = try container.decode(Int.self, forKey: .clickLimit)
        let showLimit = try container.decode(Int.self, forKey: .showLimit)
        let adPools = try container.decode([AdPool].self, forKey: .adPools)
        let adScenes = try container.decode([AdSceneGroup].self, forKey: .adScenes)

        let adLimits = try container.decodeIfPresent(AdLimitConfig.self, forKey: .adLimits) ?? .default

        let state = try container.decodeIfPresent(Int.self, forKey: .state) ?? 1

        let platformConfig = try container.decodeIfPresent(AdPlatformConfig.self, forKey: .platformConfig)

        self.init(version: version, clickLimit: clickLimit, showLimit: showLimit, state: state, adLimits: adLimits, adPools: adPools, adScenes: adScenes, platformConfig: platformConfig)
    }

    enum CodingKeys: String, CodingKey {
        case version, clickLimit, showLimit, state, adLimits, adPools, adScenes, platformConfig
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(clickLimit, forKey: .clickLimit)
        try container.encode(showLimit, forKey: .showLimit)
        try container.encode(state, forKey: .state)
        try container.encode(adLimits, forKey: .adLimits)
        try container.encode(adPools, forKey: .adPools)
        try container.encode(adScenes, forKey: .adScenes)
        try container.encodeIfPresent(platformConfig, forKey: .platformConfig)
    }

    // MARK: - Empty Config
    public static let emptyConfig = AdConfig(
        version: -1,
        clickLimit: 0,
        showLimit: 0,
        state: 0,
        adLimits: .default,
        adPools: [],
        adScenes: []
    )
}

// MARK: - AdConfig Extensions（findAdScene, findAdUnitByScene 等辅助方法）

public extension AdConfig {

    func findAdScene(_ sceneName: String) -> AdScene? {
        return scenes[sceneName]
    }

    func findAdUnitByScene(_ sceneName: String) -> [AdUnit] {
        guard let scene = findAdScene(sceneName) else { return [] }
        return scene.adPools.compactMap { pools[$0] }.flatMap { $0.adUnits }
    }

    /// 找出所有配置了 loadOnStart=1 的 AdUnit
    func findAllStartLoadUnits() -> [AdUnit] {
        return adPools
            .filter { $0.loadOnStart == 1 && $0.state == 1 }
            .flatMap { $0.adUnits }
            .filter { $0.state == 1 }
    }
    
    public func isEnabled() -> Bool {
        return state == 1
    }
}

private extension Result {
    var failure: Failure? {
        guard case .failure(let e) = self else { return nil }
        return e
    }
}

// MARK: - AdConfig 扩展（对应 Kotlin fun AdUnit.getAdPool()）
//
// Kotlin 原版通过扩展函数 AdUnit.getAdPool() 从 SilverAd.currentConfig 反查所属 AdPool
// iOS 侧挂在 AdConfig 上更符合 Swift 习惯

extension AdConfig {
    /// 查找 adUnit 所属的 AdPool（对应 Kotlin getAdPool 扩展函数）
    func getAdPool(for adUnit: AdUnit) -> AdPool? {
        adPools.first { pool in pool.adUnits.contains(adUnit) }
    }
}

extension AdUnit {
    func asDict() -> [String: Any?] {
        
        var extras : [String: Any?] = [:]
        
        extras["ad_type"] = type.rawValue
        extras["unit_name"] = name
        extras["platform_ad_unit"] = adId
        extras["platform"] = platform
        extras["auto_fill"] = autoFill
        extras["ecpm"] = ecpm
        
        return extras
    }
}



public struct AdFormatLimitConfig: Codable {

    /// 24h 内最大展示次数（0 = 不限制）
    public let daily24hShowLimit: Int

    /// 24h 内最大点击次数（0 = 不限制）
    public let daily24hClickLimit: Int

    /// 单个广告最大点击次数（0 = 不限制）
    public let singleAdClickLimit: Int

    public init(
        daily24hShowLimit:  Int = -1,
        daily24hClickLimit: Int = -1,
        singleAdClickLimit: Int = -1
    ) {
        self.daily24hShowLimit  = daily24hShowLimit
        self.daily24hClickLimit = daily24hClickLimit
        self.singleAdClickLimit = singleAdClickLimit
    }

    public var isUnlimited: Bool {
        daily24hShowLimit == -1 && daily24hClickLimit == -1 && singleAdClickLimit == -1
    }

    /// 完全不限制
    public static let unlimited = AdFormatLimitConfig()
}

public struct AdLimitConfig: Codable {

    public let inter: AdFormatLimitConfig?
    public let native: AdFormatLimitConfig?
    public let reward: AdFormatLimitConfig?
    public let appopen: AdFormatLimitConfig?

    public init(
        inter   :   AdFormatLimitConfig? = nil,
        native  :   AdFormatLimitConfig? = nil,
        reward  :   AdFormatLimitConfig? = nil,
        appopen :   AdFormatLimitConfig? = nil
    ) {
        self.inter      = inter
        self.native     = native
        self.appopen    = appopen
        self.reward     = reward
    }
 

    /// 根据广告格式取对应限制配置
    public func config(for format: AdFormat) -> AdFormatLimitConfig {
        switch format {
        case .ad_interstitial, .ad_reward_interstitial:
            return inter ?? .unlimited
        case .ad_native:
            return native ?? .unlimited
        case .ad_reward:
            return reward ?? .unlimited
        case .ad_splash:
            return appopen ?? .unlimited
        default:
            return .unlimited
        }
    }

    public static let `default` = AdLimitConfig()
}
