// LimitRecorder.swift
// Translated from LimitRecorder.kt
//
// 翻译说明：
// - Android SharedPreferences          →  UserDefaults
// - Kotlin Gson 序列化                  →  Swift Codable + JSONEncoder/Decoder
// - Kotlin @SerializedName("d"/"c"/"t") →  Swift CodingKeys
// - Kotlin SimpleDateFormat            →  DateFormatter
// - Kotlin synchronized(this){}        →  NSLock
// - Kotlin data class AdLimitRecord    →  Swift struct AdLimitRecord: Codable

import Foundation

// MARK: - LimitRecorder

final class LimitRecorder {

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var cachedRecord: AdLimitRecord?

    private static let recordKey = "ad_limit_record"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 数据结构（对应 Kotlin data class AdLimitRecord）

    struct AdLimitRecord: Codable {
        /// 对应 @SerializedName("d") var date
        var date: String = LimitRecorder.today()
        /// 对应 @SerializedName("c") var counts: MutableMap<String, Int>
        var counts: [String: Int] = [:]
        /// 对应 @SerializedName("t") var times: MutableMap<String, Long>
        var times: [String: Int64] = [:]

        enum CodingKeys: String, CodingKey {
            case date   = "d"
            case counts = "c"
            case times  = "t"
        }
    }

    // MARK: - 日期工具（对应 Kotlin companion object today()）

    static func today() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: Date())
    }

    // MARK: - 带缓存的记录读取（对应 Kotlin loadRecordCached）

    private func loadRecordCached() -> AdLimitRecord {
        if var cached = cachedRecord {
            // 日期变更时重置计数（对应 Kotlin if (it.date != today()) { it.counts.clear() }）
            if cached.date != LimitRecorder.today() {
                cached.date = LimitRecorder.today()
                cached.counts.removeAll()
                cachedRecord = cached
            }
            return cached
        }
        let record = loadRecord()
        cachedRecord = record
        return record
    }

    /// 从 UserDefaults 加载，日期不一致时返回新记录（对应 Kotlin loadRecord）
    private func loadRecord() -> AdLimitRecord {
        guard
            let data = defaults.data(forKey: Self.recordKey),
            let record = try? JSONDecoder().decode(AdLimitRecord.self, from: data),
            record.date == LimitRecorder.today()
        else {
            return AdLimitRecord()
        }
        return record
    }

    /// 持久化到 UserDefaults（对应 Kotlin saveRecord）
    private func saveRecord(_ record: AdLimitRecord) {
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.recordKey)
        }
    }

    // MARK: - 写操作

    @discardableResult
    func incrementSpecialAmount(key: String) -> Int {
        lock.withLock {
            var record = loadRecordCached()
            let current = record.counts[key] ?? 0
            let newValue = current + 1
            record.counts[key] = newValue
            cachedRecord = record
            saveRecord(record)
            return newValue
        }
    }

    func setSpecialAmount(key: String, amount: Int) {
        lock.withLock {
            var record = loadRecordCached()
            record.counts[key] = amount
            cachedRecord = record
            saveRecord(record)
        }
    }
    
    func updateAmountByMaxValue(key: String, amount: Int){
        lock.withLock {
            var record = loadRecordCached()
            if (amount > record.counts[key] ?? 0){
                
                record.counts[key] = amount
                cachedRecord = record
                saveRecord(record)
                
            }
        }
    }

    func updateLatestAdShowTime(key: String) {
        lock.withLock {
            var record = loadRecordCached()
            record.times[key] = Int64(Date().timeIntervalSince1970 * 1000) // ms
            cachedRecord = record
            saveRecord(record)
        }
    }

    // MARK: - 读操作

    /// 读取某 key 的展示/点击计数（对应 Kotlin peekAmount）
    func peekAmount(key: String) -> Int {
        lock.withLock {
            return loadRecordCached().counts[key] ?? 0
        }
    }
    /// 一次读取多个 key 的计数，减少重复加锁开销
    /// - Returns: [key: count]，不存在的 key 默认为 0
    func peekAmounts(keys: [String]) -> [String: Int] {
        lock.withLock {
            let counts = loadRecordCached().counts
            return Dictionary(uniqueKeysWithValues: keys.map { ($0, counts[$0] ?? 0) })
        }
    }

    /// 读取某 key 的最后时间戳（ms，对应 Kotlin peekTime）
    func peekTime(key: String) -> Int64 {
        lock.withLock {
            return loadRecordCached().times[key] ?? 0
        }
    }

    /// 清空所有数据（对应 Kotlin reset）
    func reset() {
        lock.withLock {
            let fresh = AdLimitRecord()
            cachedRecord = fresh
            saveRecord(fresh)
        }
    }
}
