// AdRequestLimiter.swift
// Translated from AdRequestLimiter.kt
//
// 翻译说明：
// - Kotlin kotlinx.coroutines.sync.Semaphore  →  Swift AsyncSemaphore（自定义，见下方）
//   Swift 标准库无 async Semaphore；用 actor + continuation 实现等效语义
// - Kotlin ConcurrentHashMap<String, Semaphore>
//     →  Dictionary<String, AsyncSemaphore> + NSLock（guards 本身需要线程安全访问）
// - Kotlin semaphore.withPermit { action() }
//     →  await semaphore.withPermit { await action() }
// - 并发数配置保持与 Kotlin 一致：
//     global=8, BANNER=2, NATIVE=3, 其他=1

import Foundation

// MARK: - AdRequestLimiter

enum AdRequestLimiter {

    // 全局并发上限（对应 Kotlin private val global = Semaphore(8)）
    private static let global = AsyncSemaphore(permits: 8)

    // 按 adId 维度的并发控制（对应 Kotlin private val guards = ConcurrentHashMap<String, Semaphore>()）
    private static var guards = [String: AsyncSemaphore]()
    private static let guardsLock = NSLock()

    private static func semaphore(for adUnit: AdUnit) -> AsyncSemaphore {
        guardsLock.lock()
        defer { guardsLock.unlock() }

        if let existing = guards[adUnit.adId] { return existing }

        let permits: Int
        switch adUnit.type {
        case .ad_banner: permits = 2
        case .ad_native: permits = 3
        default:       permits = 1
        }
        let sem = AsyncSemaphore(permits: permits)
        guards[adUnit.adId] = sem
        return sem
    }

    // MARK: - withGlobalPermit（对应 Kotlin suspend fun withGlobalPermit）

    static func withGlobalPermit<T>(
        adUnit: AdUnit,
        action: () async -> T
    ) async -> T {
        if await global.availablePermits == 0 {
            SilverAdLog.w("AdRequestLimiter: global busy!!")
        }
        return await global.withPermit { await action() }
    }

    // MARK: - withPermit（对应 Kotlin suspend fun withPermit）

    static func withPermit<T>(
        adUnit: AdUnit,
        action: () async -> T
    ) async -> T {
        let semaphore = semaphore(for: adUnit)
        if await semaphore.availablePermits == 0 {
            SilverAdLog.w("AdRequestLimiter: semaphore busy!!")
        }
        return await semaphore.withPermit { await action() }
    }
}

// MARK: - AsyncSemaphore
//
// Swift 标准库没有 async-aware Semaphore。
// 用 actor 实现：permits 用完时将 continuation 加入等待队列，
// 释放时唤醒队首，与 kotlinx.coroutines.sync.Semaphore 语义完全等价。

actor AsyncSemaphore {

    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(permits: Int) {
        self.permits = permits
    }

    var availablePermits: Int { permits }

    // 获取许可（对应 Semaphore.acquire()）
    func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }
        // 无可用许可，挂起等待
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    // 释放许可（对应 Semaphore.release()）
    func release() {
        if waiters.isEmpty {
            permits += 1
        } else {
            // 唤醒队首等待者（FIFO，与 kotlinx 一致）
            let next = waiters.removeFirst()
            next.resume()
        }
    }

    // 对应 Kotlin semaphore.withPermit { block }
    func withPermit<T>(_ action: () async -> T) async -> T {
        await acquire()
        defer { Task { self.release() } }
        return await action()
    }
}
