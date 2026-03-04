// AdLoadError.swift
// Translated from AdLoadError.kt

import Foundation
/// 广告加载异常
public class AdLoadException: Error {
    public let code: String
    public let msg: String

    public var message: String {
        return "AdLoadException: \(msg):\(code)"
    }

    public init(code: String, msg: String) {
        self.code = code
        self.msg = msg
    }

    // MARK: - Error Codes
    public static let CODE_TIMEOUT              = "1001"
    public static let CODE_SDK_ERROR            = "1002"
    public static let CODE_NOT_MATCH_PROVIDER   = "1003"
    public static let CODE_IN_OTHER_TASK        = "1004"
    public static let CODE_OTHER               = "1005"

    public static let UNKNOWN_ERROR = AdLoadException(code: CODE_OTHER, msg: "unknown")
}

extension AdLoadException: LocalizedError {
    public var errorDescription: String? { message }
}
