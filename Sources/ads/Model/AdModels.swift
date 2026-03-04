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

// MARK: - AdConfig

public struct AdConfig: Codable {
    public let version: Int
    public let clickLimit: Int
    public let showLimit: Int
    public let adPools: [AdPool]
    public let adScenes: [AdSceneGroup]

    // 懒加载 scenes Map（Swift 用 lazy var，但 struct 不支持 lazy；改为 computed + 内部缓存）
    // 用 class 包装或直接在 init 时构建
    public let scenes: [String: AdScene]
    public let pools: [String: AdPool]

    public init(version: Int, clickLimit: Int, showLimit: Int, adPools: [AdPool], adScenes: [AdSceneGroup]) {
        self.version = version
        self.clickLimit = clickLimit
        self.showLimit = showLimit
        self.adPools = adPools
        self.adScenes = adScenes

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
        self.init(version: version, clickLimit: clickLimit, showLimit: showLimit, adPools: adPools, adScenes: adScenes)
    }

    enum CodingKeys: String, CodingKey {
        case version, clickLimit, showLimit, adPools, adScenes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(clickLimit, forKey: .clickLimit)
        try container.encode(showLimit, forKey: .showLimit)
        try container.encode(adPools, forKey: .adPools)
        try container.encode(adScenes, forKey: .adScenes)
    }

    // MARK: - Empty Config
    public static let emptyConfig = AdConfig(
        version: -1,
        clickLimit: 0,
        showLimit: 0,
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
        extras["autoFill"] = autoFill
        extras["ecpm"] = ecpm
        
        return extras
    }
}
