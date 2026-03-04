// Limiter.swift
// Translated from Limiter.kt
//
// 翻译说明：
// - Kotlin interface Limiter  →  Swift protocol Limiter

import Foundation

// MARK: - Limiter Protocol

protocol Limiter: AnyObject {
    /// 记录广告展示（对应 Kotlin markAdShow）
    func markAdShow(scene: AdScene)
    /// 记录广告点击（对应 Kotlin markAdClick，同一广告只记一次）
    func markAdClick(ad: Ad, scene: AdScene)
}
