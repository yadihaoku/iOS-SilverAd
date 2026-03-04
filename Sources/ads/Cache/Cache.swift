// Cache.swift
// Translated from Cookie.kt + CacheAd.kt
//
// 翻译说明：
// - Kotlin interface Cookie          →  Swift protocol CacheAdCookie
//   （避免与 HTTP Cookie 混淆，加 CacheAd 前缀）
// - Kotlin CoroutineScope + Job      →  Swift Task（结构化并发）
// - kotlinx.coroutines.delay()      →  try await Task.sleep()
// - SystemClock.elapsedRealtime()   →  CACurrentMediaTime()（单位：秒，需转换）
// - Kotlin override hashCode/equals →  Swift Hashable + Equatable（基于 ad.uuid）
// - ad.expireTimestamp() 返回毫秒   →  iOS 侧统一用毫秒（与 BaseAd.swift 保持一致）

import Foundation
import UIKit

// MARK: - CacheAdCookie Protocol（对应 Kotlin interface Cookie）

protocol CacheAdCookie: AnyObject {
    /// 从缓存中移除并销毁广告
    func remove()
    /// 触发重新预加载
    func refill()
}

// MARK: - CacheAd（对应 Kotlin internal class CacheAd）

final class CacheAd {

    let ad: Ad

    private let cookie: CacheAdCookie

    /// 对应 Kotlin autoFillJob: Job?
    private var autoFillTask: Task<Void, Never>?

    init(ad: Ad, cookie: CacheAdCookie) {
        self.ad = ad
        self.cookie = cookie
    }

    // MARK: - 自动过期补填（对应 Kotlin scheduleAutoFill）
    //
    // Kotlin：CoroutineScope.launch { delay(leftDuration) }
    // Swift：Task { try await Task.sleep(nanoseconds:) }

    func scheduleAutoFill() {
        cancelAutoFill()

        autoFillTask = Task { [weak self] in
            guard let self else { return }
            // expireTimestamp() 返回毫秒，CACurrentMediaTime() 返回秒
            let nowMs = Double(CACurrentMediaTime() * 1000)
            SilverAdLog.d("CacheAd.scheduleAutoFill: nowMs = \(nowMs)ms")
            
            let leftMs = self.ad.expireTimestamp() - nowMs

            SilverAdLog.d("CacheAd.scheduleAutoFill: left time = \(leftMs)ms")

            guard leftMs > 0 else {
                self.onExpired()
                return
            }

            do {
                // 等待剩余存活时间（毫秒 → 纳秒）
                try await Task.sleep(nanoseconds: UInt64(leftMs) * 1_000_000)
            } catch {
                // Task 被取消时正常退出，不做处理
                return
            }

            guard !Task.isCancelled else { return }
            self.onExpired()
        }
    }

    private func onExpired() {
        // 过期：先移除，再判断是否自动补填
        cookie.remove()
        if ad.adUnit.autoRefill() {
            SilverAdLog.d("CacheAd.scheduleAutoFill: doRefill adUnit = (\(ad.adUnit))")
            cookie.refill()
        }
        autoFillTask = nil
    }

    func cancelAutoFill() {
        if let task = autoFillTask {
            SilverAdLog.d("CacheAd.cancelAutoFill: cancel autoFill -> (\(ad.adUnit))")
            task.cancel()
            autoFillTask = nil
        }
    }
}

// MARK: - Hashable & Equatable（对应 Kotlin hashCode / equals，基于 ad.uuid）

extension CacheAd: Hashable {
    static func == (lhs: CacheAd, rhs: CacheAd) -> Bool {
        lhs.ad.uuid == rhs.ad.uuid
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ad.uuid)
    }
}
