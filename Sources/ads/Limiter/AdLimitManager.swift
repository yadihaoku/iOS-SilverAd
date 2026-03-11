// AdLimitManager.swift
// Translated from AdLimitManager.kt
//
// 翻译说明：
// - Kotlin internal object AdLimitManager  →  Swift final class AdLimitManager（单例）
// - Android SharedPreferences              →  UserDefaults（LimitRecorder 内部处理）
// - Kotlin @Volatile var recorderInstance  →  NSLock + lazy init（Swift 无 @Volatile）
// - Kotlin CoroutineScope(SupervisorJob + Dispatchers.Default)
//     →  Task { await MainActor.run {} } 或直接 Task {}（后台执行）
// - Kotlin hashSetOf<String>()             →  Swift Set<String>（adClickedId 去重用）
// - Kotlin private class LimiterImpl       →  Swift private final class LimiterImpl

import Foundation

// MARK: - AdLimitManager

struct AdStat {
    let clickCount          : Int
    let showCount           : Int
    let singleAdClickCount  : Int
}

internal final class AdLimitManager {

    public static let shared = AdLimitManager()
    private init() {}

    // 对应 Kotlin private const val SP_NAME / KEY_TODAY_CLICK / KEY_TODAY_SHOW
    private let keyTodayClick = "ad_t_c"
    private let keyTodayShow  = "ad_t_s"

    // 对应 Kotlin private val adClickedId = hashSetOf<String>()（防重复点击）
    private var adClickCounts = [String : Int]()
    private let clickIdLock  = NSLock()

    // MARK: - Recorder（对应 Kotlin @Volatile recorderInstance + recorder()）
    // 懒加载，线程安全

    private var _recorder: LimitRecorder?
    private let recorderLock = NSLock()

    private func recorder() -> LimitRecorder {
        recorderLock.withLock {
            if let r = _recorder { return r }
            let r = LimitRecorder()
            _recorder = r
            return r
        }
    }

    // MARK: - 公开查询 API（对应 Kotlin getAdClickCount / getAdIntervalLimitCount 等）

    func getAdClickCount() -> Int {
        recorder().peekAmount(key: keyTodayClick)
    }

    func getAdClickCount(scene: String) -> Int {
        recorder().peekAmount(key: buildAdClickKey(scene))
    }

    func getAdIntervalLimitCount(scene: String) -> Int {
        recorder().peekAmount(key: buildAdIntervalLimitKey(scene))
    }

    func incrementAdLimitCount(scene: String) {
        recorder().incrementSpecialAmount(key: buildAdIntervalLimitKey(scene))
    }

    func getAdLastShowTime(scene: String) -> Int64 {
        recorder().peekTime(key: buildAdTimeKey(scene))
    }
    
    func getAdTypeShowCount(type : AdFormat) -> Int {
        recorder().peekAmount(key: buildAdTypeShowKey(type))
    }
    func getAdTypeClickCount(type : AdFormat) -> Int {
        recorder().peekAmount(key: buildAdTypeClickKey(type))
    }
    func getSingleAdClickCount(type : AdFormat) -> Int {
        recorder().peekAmount(key: buildAdTypeSingleAdClickKey(type))
    }
    
    func getAdTypeStat(type : AdFormat) -> AdStat{
        
        let showKey = buildAdTypeShowKey(type)
        let clickKey = buildAdTypeClickKey(type)
        let singAdKey = buildAdTypeSingleAdClickKey(type)
        let data = recorder().peekAmounts(keys: [showKey, clickKey, singAdKey])
        
        return AdStat(clickCount: data[clickKey] ?? 0, showCount: data[showKey] ?? 0, singleAdClickCount: data[singAdKey] ?? 0)
    }
    
    func getSingleAdStat() ->[AdFormat : Int]{
        // 遍历所有 case
        var allKeys = AdFormat.allCases.map { buildAdTypeSingleAdClickKey($0)        }
        var data = recorder().peekAmounts(keys: allKeys)
        
        return Dictionary(uniqueKeysWithValues: AdFormat.allCases.map { ($0, data[buildAdTypeSingleAdClickKey($0)] ?? 0) })
    }
    
    // MARK: - Key 构造（对应 Kotlin private fun buildXxxKey）

    private func buildAdTimeKey(_ scene: String)          -> String { "lastest_show_\(scene)" }
    private func buildAdIntervalLimitKey(_ scene: String) -> String { "interval_limit_\(scene)" }
    private func buildAdClickKey(_ scene: String)         -> String { "ad_click_\(scene)" }
    private func buildAdTypeClickKey(_ type: AdFormat)    -> String { "ad_click_with_\(type.rawValue)"}
    private func buildAdTypeShowKey(_ type: AdFormat)     -> String { "ad_show_with_\(type.rawValue)"}
    // 单个广告实例 当日点击的最大次数
    private func buildAdTypeSingleAdClickKey(_ type: AdFormat)     -> String { "ad_click_with_single_\(type.rawValue)"}

    // MARK: - 展示 & 点击记录（对应 Kotlin markAdShowInternal / markAdClickInternal）

    private func markAdShowInternal(ad: Ad, scene: AdScene) {
        // 对应 Kotlin scope.launch { ... }：后台 Task 执行，不阻塞调用方
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            
            let adTypeShowKey = buildAdTypeShowKey(ad.format)

            let rec = recorder()
            
            // 当日展示次数
            let tsc = rec.incrementSpecialAmount(key: self.keyTodayShow)
            // 当日该类型展示次数
            let ttsc = rec.incrementSpecialAmount(key: adTypeShowKey)
            // 该场景最后一次展示时间
            rec.updateLatestAdShowTime(key: self.buildAdTimeKey(scene.sceneName))
            // 当日该场景展示次数
            rec.setSpecialAmount(key: self.buildAdIntervalLimitKey(scene.sceneName), amount: 0)
            
            SilverAdLog.d("markAdShow: \(scene.sceneName) tsc=\(tsc) ttsc=\(ttsc)")
        }
    }

    private func markAdClickInternal(ad: Ad, scene: AdScene) {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            
            let adTypeClickKey = buildAdTypeClickKey(ad.format)
            let rec = recorder()
            
            // 当日 该场景 广告点击次数
            let clickCount = rec.incrementSpecialAmount(key: self.buildAdClickKey(scene.sceneName))
            SilverAdLog.d("markAdClick: \(scene.sceneName)  click amount:\(clickCount)")
            // 累加总的广告点击次数
            rec.incrementSpecialAmount(key: self.keyTodayClick)
            // 累加当时该类型广告的点击次数
            rec.incrementSpecialAmount(key: adTypeClickKey)
        }
    }
    
    // MARK: - 单个广告点击计数核心逻辑

    /// 记录点击，返回当前该广告累计点击次数
    /// - Returns: 本次点击后的累计次数
    @discardableResult
    private func incrementClickCount(for ad: Ad) -> Int {
        clickIdLock.withLock {
            let newCount = (adClickCounts[ad.uuid] ?? 0) + 1
            adClickCounts[ad.uuid] = newCount
            
            recorder().updateAmountByMaxValue(key: buildAdTypeSingleAdClickKey(ad.format), amount: newCount)
            
            return newCount
        }
    }

    // MARK: - Reset（对应 Kotlin fun reset）

    func reset() {
        recorder().reset()
    }

    // MARK: - 创建 Limiter（对应 Kotlin fun buildLimiter(context)）

    func buildLimiter() -> Limiter {
        LimiterImpl(manager: self)
    }

    // MARK: - LimiterImpl（对应 Kotlin private class LimiterImpl : Limiter）

    private final class LimiterImpl: Limiter {

        private weak var manager: AdLimitManager?

        init(manager: AdLimitManager) {
            self.manager = manager
        }

        func markAdShow(ad: Ad, scene: AdScene) {
            manager?.markAdShowInternal(ad: ad, scene: scene)
        }

        func markAdClick(ad: Ad, scene: AdScene) {
            guard let manager else { return }

            // 1. 递增点击次数（无论第几次都记录）
            let clickCount = manager.incrementClickCount(for: ad)
            SilverAdLog.d("markAdClick: uuid=\(ad.uuid) count=\(clickCount)")

            // 2. 第一次点击才计入 24h 统计（防止同一广告刷点击数据）
            if clickCount == 1 {
                manager.markAdClickInternal(ad: ad, scene: scene)
            }
        }
    }
}
