// CacheManager.swift
// Translated from CacheManager.kt
//
// 翻译说明：
// - Kotlin synchronized(this){}         →  NSLock（与 BaseAd 保持一致）
// - Kotlin CopyOnWriteArraySet          →  遍历时先复制 Set（Swift 无 CopyOnWrite 容器）
// - Kotlin HashSet<CacheAd>             →  Swift Set<CacheAd>（CacheAd 已实现 Hashable）
// - Kotlin inner class CookieImpl       →  Swift private final class CacheManagerCookie
// - 排序逻辑：sortedBy { -it.adUnit.ecpm } → sorted { $0.adUnit.ecpm > $1.adUnit.ecpm }
//   （Kotlin 用负号实现降序，Swift 直接用比较器）

import Foundation
import UIKit

// MARK: - CacheManager

final class CacheManager {

    private var cache = AdCacheSet()
    private let lock = NSLock()
    
    // MARK: - 移除指定广告

    @discardableResult
    func removeCachedAd(_ ad: Ad) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        return removeAdInternal(ad)
    }
    // MARK: - 销毁某 adUnit 的全部缓存

    func destroyCachedAd(adUnit: AdUnit) {
        lock.lock()
        defer { lock.unlock() }

        let removed = cache.removeAll { $0.ad.adUnit == adUnit }
        removed.forEach { $0.ad.destroy() }
    }

    // MARK: - 清理过期广告（内部调用，调用前须已持有锁）

    private func clearExpiredAd() {
        cache.removeAll { item in
            let ad = item.ad
            let expired = ad.isExpired() || !ad.isReady()
            if expired {
                SilverAdLog.d("CacheManager: remove expired ad for adUnit (\(ad.adUnit.desc()))")
            }
            return expired
        }
    }
    
    private func removeAdInternal(_ ad: Ad) -> Bool{
        var removed = false
        cache.removeAll { item in
            let isSame = item.ad === ad          // 引用相等（对应 Kotlin ads === it.ad）
            if isSame {
                item.cancelAutoFill()
                SilverAdLog.d("removeCachedAd \(item.ad)")
                removed = true
            }
            return isSame
        }
        return removed
    }

    // MARK: - 入队缓存

    func enqueueCache(_ ad: Ad) {
        lock.lock()
        defer { lock.unlock() }

        clearExpiredAd()

        guard ad.isReady() && !ad.isExpired() else {
            SilverAdLog.w("enqueueCache: cancel! ad is unavailable! \(ad)")
            return
        }

        if cache.containsAd(ad) {
            SilverAdLog.w("enqueueCache: \(ad.adUnit.desc()) already in cache pool!")
            SilverAdLog.w("-> current ad: \(ad)")
        } else {
            SilverAdLog.w("enqueueCache: ad: \(ad)")
            let cacheAd = CacheAd(ad: ad, cookie: makeCookie(for: ad))
            cacheAd.scheduleAutoFill()
            cache.insert(cacheAd)
        }
    }

    // MARK: - 查询是否已缓存

    func isCachedByAdUnit(_ adUnit: AdUnit) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        clearExpiredAd()
        let isCached = cache.containsAdUnit(adUnit)
        SilverAdLog.d("isCachedByAdUnit: \(isCached) : (\(adUnit))")
        return isCached
    }

    // MARK: - 取出最高 eCPM 广告（对应 Kotlin pickElderlyAd，实际按 eCPM 降序）
    //
    // Kotlin 注释说"返回缓存最久的广告"，但实际排序是 sortedBy { -ecpm }（按 eCPM 降序）
    // Swift 侧保持与 Kotlin 实现一致，按 eCPM 降序取第一个可成功移除的广告

    func pickAd(matching adUnits: [AdUnit]) -> Ad? {
        lock.withLock {
            
            guard !cache.isEmpty else { return nil }
            
            clearExpiredAd()
            
            let candidates = cache
                .filter { adUnits.contains($0.ad.adUnit) }
                .sorted {
                   if $0.ad.adUnit.ecpm != $1.ad.adUnit.ecpm {
                       $0.ad.adUnit.ecpm > $1.ad.adUnit.ecpm
                   }else{
                       // 2. ecpm 相同时，有效期较短（更快过期）的优先
                       $0.ad.expireTimestamp() < $1.ad.expireTimestamp()
                   }
                }
                .map { $0.ad }
            // 对应 sortedBy { -it.adUnit.ecpm }
            SilverAdLog.d("pickAd: adUnits = \(adUnits)")
            SilverAdLog.d("pickAd: sorted candidates = \(candidates)")
            let ad = candidates.first { removeAdInternal($0) }   // 对应 firstOrNull { removeCachedAd(it) }
            SilverAdLog.d("pickAd: ad Object candidates = \(String(describing: ad))")
            
            return ad
        }
    }

    func pickAd(for adUnit: AdUnit) -> Ad? {
        pickAd(matching: [adUnit])
    }

    // MARK: - 销毁全部

    func destroyAll() {
        lock.lock()
        defer { lock.unlock() }

        cache.forEach { $0.ad.destroy() }
        cache.removeAll()
    }

    // MARK: - 创建 Cookie（对应 Kotlin inner class CookieImpl）

    private func makeCookie(for ad: Ad) -> CacheAdCookie {
        CacheManagerCookie(ad: ad, manager: self)
    }
}

// MARK: - CacheManagerCookie（对应 Kotlin inner class CookieImpl : Cookie）

private final class CacheManagerCookie: CacheAdCookie {

    private let ad: Ad
    private weak var manager: CacheManager?

    init(ad: Ad, manager: CacheManager) {
        self.ad = ad
        self.manager = manager
    }

    func remove() {
        ad.destroy()
        manager?.removeCachedAd(ad)
    }

    func refill() {
        SilverAd.shared.preloadAdWithAutoFill(adUnit: ad.adUnit)
    }
}

// MARK: - AdCacheSet（对应 Kotlin private class AdSet : HashSet<CacheAd>）
//
// 封装 Set<CacheAd> 并提供按 adUnit / ad 实例查询的辅助方法
// removeAll(where:) 返回被移除的元素列表（Kotlin removeIf 只返回 Boolean）

private struct AdCacheSet {

    private var storage = Set<CacheAd>()

    var isEmpty: Bool { storage.isEmpty }

    func forEach(_ body: (CacheAd) -> Void) { storage.forEach(body) }

    func filter(_ predicate: (CacheAd) -> Bool) -> [CacheAd] {
        storage.filter(predicate)
    }

    mutating func insert(_ item: CacheAd) {
        storage.insert(item)
    }

    mutating func removeAll() {
        storage.removeAll()
    }

    /// 移除满足条件的元素，返回被移除的元素列表
    @discardableResult
    mutating func removeAll(where condition: (CacheAd) -> Bool) -> [CacheAd] {
        var removed = [CacheAd]()
        // 遍历快照避免修改时迭代（对应 Kotlin CopyOnWriteArraySet）
        for item in storage where condition(item) {
            storage.remove(item)
            removed.append(item)
        }
        return removed
    }

    // MARK: - 查询

    func containsAdUnit(_ unit: AdUnit) -> Bool {
        storage.contains { $0.ad.adUnit == unit }
    }

    func containsAd(_ ad: Ad) -> Bool {
        storage.contains { $0.ad === ad }
    }
}
