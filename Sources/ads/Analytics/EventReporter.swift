// EventReporter.swift
// Translated from EventReporter.kt
//
// 翻译说明：
// - Kotlin internal object EventReporter     →  Swift enum EventReporter（无实例，纯命名空间）
// - Kotlin private var reporterImpl          →  nonisolated(unsafe) static var，允许运行时替换
// - Kotlin buildMap { propertiesBlock }      →  Swift trailing closure 构建 [String: Any]
// - Kotlin object DefaultReporter            →  Swift private class DefaultReporter
// - 三个重载 report() 函数保持一致

import Foundation

// MARK: - EventReporter

public enum EventReporter {

    // 对应 Kotlin private var reporterImpl: AdReporter = DefaultReporter
    // nonisolated(unsafe)：允许从任意线程设置，调用方需自行保证线程安全（与 Kotlin 原版一致）
    nonisolated(unsafe) private static var reporterImpl: AdReporter = DefaultReporter()

    public static func updateReporter(_ reporter: AdReporter) {
        reporterImpl = reporter
    }

    // MARK: - 三个重载（对应 Kotlin 三个 report 方法）

    /// 带 EventData + properties 闭包（对应 Kotlin report(event, eventData, propertiesBlock)）
    public static func report(
        event: String,
        eventData: EventData?,
        properties propertiesBlock: (inout [String: Any]) -> Void = { _ in }
    ) {
        var props = [String: Any]()
        propertiesBlock(&props)
        reportInternal(event: event, eventData: eventData, extras: props.mapValues { $0 as Any })
    }

    /// 只带 properties 闭包，无 EventData（对应 Kotlin report(event, propertiesBlock)）
    public static func report(
        event: String,
        properties propertiesBlock: (inout [String: Any]) -> Void = { _ in }
    ) {
        var props = [String: Any]()
        propertiesBlock(&props)
        reportInternal(event: event, eventData: nil, extras: props.mapValues { $0 as Any })
    }

    /// 带 EventData + extras 字典（对应 Kotlin report(event, eventData, extras)）
    public static func report(
        event: String,
        extras: [String: Any]? = nil
    ) {
        reportInternal(event: event, eventData: nil, extras: extras)
    }
    /// 带 EventData + extras 字典（对应 Kotlin report(event, eventData, extras)）
    public static func report(
        event: String,
        eventData: EventData?,
        extras: [String: Any]? = nil
    ) {
        reportInternal(event: event, eventData: eventData, extras: extras)
    }
    /// 带 EventData + extras 字典（对应 Kotlin report(event, eventData, extras)）
    public static func report(
        event: String,
        eventData: EventData?,
    ) {
        reportInternal(event: event, eventData: eventData, extras: nil)
    }
    
    private static func reportInternal(event: String, eventData: EventData?, extras: [String: Any]?){
        Task{
            reporterImpl.reportEvent(event: event, eventData: eventData, extras: extras)
        }
    }
}

// MARK: - DefaultReporter（对应 Kotlin private object DefaultReporter）

private final class DefaultReporter: AdReporter {
    func reportEvent(event: String, eventData: EventData?, extras: [String: Any]?) {
        SilverAdLog.i("reportEvent: \(event) | eventData=\(String(describing: eventData)) | extras=\(String(describing: extras))")
    }
}
