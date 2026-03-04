// Log.swift
// Translated from Log.java
//
// 翻译说明：
// - Java BiConsumer<String,String> + enum LogImpl  →  Swift enum + 函数类型
// - android.util.Log                               →  os.Logger（Apple 统一日志）
// - 长文本分段打印逻辑保持一致
// - static var sDebug                              →  static var isDebug（Swift 命名习惯）

import Foundation
import os.log

public enum SilverAdLog {

    public static var isDebug: Bool = true
    public static let lineMax: Int = 3000
    private static let tag = "SilverAd"
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SilverAd", category: tag)

    // MARK: - 内部打印（对应 Java printInternal）

    private static func printInternal(level: Level, args: [String]) {
        guard isDebug else { return }

        let str = args.isEmpty ? "e: ''" : args.joined()

        if str.count <= lineMax {
            log(level: level, msg: str)
            return
        }

        // 超长时分段打印（对应 Java while 循环）
        var remaining = str
        var i = 0
        while remaining.count > lineMax {
            let end = remaining.index(remaining.startIndex, offsetBy: lineMax)
            log(level: level, msg: "\(i)\t\(remaining[..<end])")
            remaining = String(remaining[end...])
            i += 1
        }
        log(level: level, msg: "\(i)\t\(remaining)")
    }

    private static func log(level: Level, msg: String) {
        switch level {
        case .verbose: logger.debug("V \(msg)")
        case .debug:   logger.debug("\(msg)")
        case .warn:    logger.warning("\(msg)")
        case .info:    logger.info("\(msg)")
        }
    }

    // MARK: - 公开 API（对应 Java 静态方法）

    public static func v(_ tag: String, _ args: String...) {
        guard isDebug else { return }
        printInternal(level: .verbose, args: ["\(tag): "] + args)
    }

    public static func d(_ args: String...) {
        guard isDebug else { return }
        printInternal(level: .debug, args: args)
    }

    public static func w(_ args: String...) {
        guard isDebug else { return }
        printInternal(level: .warn, args: args)
    }

    public static func i(_ args: String...) {
        guard isDebug else { return }
        printInternal(level: .info, args: args)
    }

    // MARK: - 内部 Level 枚举
    private enum Level { case verbose, debug, warn, info }
}
