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

internal final class AdLimitManager {

    public static let shared = AdLimitManager()
    private init() {}

    // 对应 Kotlin private const val SP_NAME / KEY_TODAY_CLICK / KEY_TODAY_SHOW
    private let keyTodayClick = "ad_t_c"
    private let keyTodayShow  = "ad_t_s"

    // 对应 Kotlin private val adClickedId = hashSetOf<String>()（防重复点击）
    private var adClickedIds = Set<String>()
    private let clickIdLock  = NSLock()

    // MARK: - Recorder（对应 Kotlin @Volatile recorderInstance + recorder()）
    // 懒加载，线程安全

    private var _recorder: LimitRecorder?
    private let recorderLock = NSLock()

    private func recorder() -> LimitRecorder {
        recorderLock.lock()
        defer { recorderLock.unlock() }
        if let r = _recorder { return r }
        let r = LimitRecorder()
        _recorder = r
        return r
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

    // MARK: - Key 构造（对应 Kotlin private fun buildXxxKey）

    private func buildAdTimeKey(_ scene: String)          -> String { "lastest_show_\(scene)" }
    private func buildAdIntervalLimitKey(_ scene: String) -> String { "interval_limit_\(scene)" }
    private func buildAdClickKey(_ scene: String)         -> String { "ad_click_\(scene)" }

    // MARK: - 展示 & 点击记录（对应 Kotlin markAdShowInternal / markAdClickInternal）

    private func markAdShowInternal(scene: AdScene) {
        let rec = recorder()
        // 对应 Kotlin scope.launch { ... }：后台 Task 执行，不阻塞调用方
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            SilverAdLog.d("markAdShow: \(scene.sceneName)")
            rec.incrementSpecialAmount(key: self.keyTodayShow)
            rec.updateLatestAdShowTime(key: self.buildAdTimeKey(scene.sceneName))
            rec.setSpecialAmount(key: self.buildAdIntervalLimitKey(scene.sceneName), amount: 0)
        }
    }

    private func markAdClickInternal(scene: AdScene) {
        let rec = recorder()
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            
            let clickCount = rec.incrementSpecialAmount(key: self.buildAdClickKey(scene.sceneName))
            SilverAdLog.d("markAdClick: \(scene.sceneName)  click amount:\(clickCount)")
            rec.incrementSpecialAmount(key: self.keyTodayClick)
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

        func markAdShow(scene: AdScene) {
            manager?.markAdShowInternal(scene: scene)
        }

        func markAdClick(ad: Ad, scene: AdScene) {
            guard let manager else { return }

            // 对应 Kotlin if (adClickedId.contains(ad.uuid)) { return }
            manager.clickIdLock.lock()
            let alreadyClicked = manager.adClickedIds.contains(ad.uuid)
            if !alreadyClicked { manager.adClickedIds.insert(ad.uuid) }
            manager.clickIdLock.unlock()

            guard !alreadyClicked else { return }
            manager.markAdClickInternal(scene: scene)
        }
    }
}
