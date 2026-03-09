// BaseAd.swift
// Translated from BaseAd.kt
//
// 设计说明：
// - Kotlin abstract class → Swift open class（Swift 没有 abstract，用 open + fatalError 模拟）
// - Android SystemClock.elapsedRealtime() → CACurrentMediaTime()（单位: 秒）
// - Kotlin suspend fun → Swift async throws func
// - Kotlin inner class CallbackDelegate → Swift nested class（需持有 weak parent 引用）

import Foundation
import UIKit

// MARK: - BaseAd
open class BaseAd:NSObject, Ad {

    // MARK: Ad Protocol Requirements
    open var format: AdFormat { fatalError("Subclass must override format") }
    public let providerName: String
    public let adUnit: AdUnit
    public private(set) var uuid: String = UUID().uuidString
    
    private var limiter: Limiter?

    public var currentAdScene: AdScene? {
        didSet {
            // 对应 Kotlin set(value) { field = value; updateEvent { scene = field?.sceneName } }
            updateEvent { [weak self] data in
                data.scene = self?.currentAdScene?.sceneName
                data.extras["scene"] = self?.currentAdScene?.sceneName
            }
        }
    }
    
    /// 对应 Kotlin internal fun buildEventData() = reportData.copy()
      /// Swift struct 赋值即是值拷贝，与 Kotlin copy() 语义完全等价
      func buildEventData() -> EventData {
          return reportData   // struct 值拷贝
      }

      /// 对应 Kotlin @Synchronized fun updateEvent(block: EventData.() -> Unit)
      func updateEvent(_ block: (inout EventData) -> Void) {
          block(&reportData)
      }
    
    private lazy var reportData: EventData = {
            var extras = [String: Any?]()
            // 对应 Kotlin adUnit.getAdPool()?.let { extras.put("page_name", it.name) }
            if let pool = SilverAd.shared.currentConfig.getAdPool(for: adUnit) {
                extras["page_name"] = pool.name
            }
            extras["uuid"] = uuid
            extras.merge(adUnit.asDict()) { v1, v2 in
                return v2
            }
        
            return EventData(
                scene: currentAdScene?.sceneName,
                adUnit: adUnit,
                currencyCode: "USD",
                micros: -1,
                revenuePrecision: nil,
                extras: extras
            )
        }()

    // MARK: Internal State
    private(set) var mIsReady = false
    private var mStartLoadStamp: TimeInterval = 0
    private var mAdLoadedTime: TimeInterval = 0       // CACurrentMediaTime()

    // MARK: Callback
    public lazy var delegate = CallbackDelegate(parent: self)

    // MARK: Init
    public init(adUnit: AdUnit, providerName_: String) {
        self.adUnit = adUnit
        self.providerName = providerName_
    }

    // MARK: - Time Helpers

    private func markLoadTime() {
        mStartLoadStamp = CACurrentMediaTime()
    }

    func markReady() {
        mIsReady = true
        if mAdLoadedTime == 0 {
            mAdLoadedTime = CACurrentMediaTime() * 1000
        }
    }

    public func adLoadTime() -> TimeInterval {
        return mAdLoadedTime
    }

    public func expireTimestamp() -> TimeInterval {
        return mAdLoadedTime + adUnit.ttl
    }

    public func isExpired() -> Bool {
        return CACurrentMediaTime() * 1000  >= expireTimestamp()
    }

    public final func load() async -> Result<Bool, Error> {
        SilverAdLog.d("Load Ad -> \(adUnit.desc())")
        markLoadTime()
        // 对应 Kotlin initLimiter(context)
        limiter = AdLimitManager.shared.buildLimiter()

        let startTime = CACurrentMediaTime()
        let result: Result<Bool, Error>
        do {
            let success = try await safeLoad()
            result = .success(success)
        } catch {
            result = .failure(error)
        }

        let loadDurationMs = Int64((CACurrentMediaTime() - startTime) * 1000)
        updateEvent {  $0.consumeTime = loadDurationMs }
        SilverAdLog.w("BaseAd.load: duration = \(loadDurationMs)ms")
        

        // 对应 Kotlin EventReporter.report(AD_LOAD_RESULT, buildEventData()) { ... }
        let loadResult: Bool
        if case .success(let val) = result { loadResult = val } else { loadResult = false }
        EventReporter.report(
            event: SilverAdEvent.adLoadResult,
            eventData: buildEventData()
        ) { props in
            props[SilverAdEvent.Param.result]        = loadResult
            props[SilverAdEvent.Param.consumeTime]   = loadDurationMs
            props[SilverAdEvent.Param.configVersion] = SilverAd.shared.currentConfig.version
            if !loadResult {
                if case .failure(let error) = result {
                    props[SilverAdEvent.Param.reason] = error.localizedDescription
                } else {
                    props[SilverAdEvent.Param.reason] = "unknown"
                }
            }
        }

        return result
    }

    /// 子类必须重写（对应 Kotlin protected abstract suspend fun safeLoadAd）
    @MainActor
    open func safeLoad() async throws -> Bool {
        fatalError("Subclass must override safeLoad()")
    }

    // MARK: - Ad Protocol
    @MainActor
    public func isReady() -> Bool {
        return mIsReady && originAd != nil
    }

    @MainActor
    public var originAd: Any? {
        return retrieveAd()
    }

    /// 子类提供底层 SDK 广告对象
    @MainActor
    open func retrieveAd() -> Any? {
        fatalError("Subclass must override retrieveAd()")
    }

    open func destroy() {
        fatalError("Subclass must override destroy()")
    }

    public func setAdCallback(_ callback: InteractionCallback) {
        delegate.callback = callback
    }

    // MARK: - Description

    public override var description: String {
        return "\(providerName)|\(adUnit.name)|expiredTime=\(expireTimestamp())|\(adUnit.adId)|ecpm: \(adUnit.ecpm)"
    }

    // MARK: - Nested CallbackDelegate（对应 Kotlin inner class CallbackDelegate）

    public final class CallbackDelegate: InteractionCallback, OnRewardCallback {

            private weak var parent: BaseAd?
            var callback: InteractionCallback?

            init(parent: BaseAd) {
                self.parent = parent
            }

            // MARK: InteractionCallback

            public func onAdClicked() {
                guard let parent else { return }
                // 对应 Kotlin currentAdScene?.let { limiter?.markAdClick(this@BaseAd, scene) }
                if let scene = parent.currentAdScene {
                    parent.limiter?.markAdClick(ad: parent, scene: scene)
                }
                EventReporter.report(event: SilverAdEvent.adClick, eventData: parent.buildEventData())
       
                callback?.onAdClicked()
                
                SilverAdLog.d("CallbackDelegate.onAdClicked")
            }

            public func onAdClosed() {
                guard let parent else { return }
                callback?.onAdClosed()
                
                EventReporter.report(event: SilverAdEvent.adClose, eventData: parent.buildEventData())
                SilverAdLog.d("CallbackDelegate.onAdClosed")
            }

            public func onAdFailedToShow() {
                checkAutoReload()
                callback?.onAdClosed()
                SilverAdLog.d("CallbackDelegate.onAdFailedToShow")
            }

            public func onAdShowed() {
                checkAutoReload()
                callback?.onAdShowed()
                SilverAdLog.d("CallbackDelegate.onAdShowed")
            }

            public func onAdImpression() {
                guard let parent else { return }
                callback?.onAdImpression()
                EventReporter.report(event: SilverAdEvent.adImpression, eventData: parent.buildEventData())
                SilverAdLog.d("CallbackDelegate.onAdImpression")
            }

            public func onAdsPaid() {
                guard let parent else { return }
                callback?.onAdsPaid()
                EventReporter.report(event: SilverAdEvent.adPaid, eventData: parent.buildEventData())
                SilverAdLog.d("CallbackDelegate.onAdsPaid \(parent.adUnit.adId) adUUID=\(parent.uuid)")
            }

            public func onReward() {
                if let rewardCallback = callback as? OnRewardCallback {
                    rewardCallback.onReward()
                }
                SilverAdLog.d("CallbackDelegate.onReward")
            }

            // MARK: - 自动补填（对应 Kotlin private fun checkAutoReload）

            private func checkAutoReload() {
                guard let parent else { return }
                // 对应 Kotlin currentAdScene?.let { limiter?.markAdShow(it) }
                if let scene = parent.currentAdScene {
                    parent.limiter?.markAdShow(scene: scene)
                }
                if parent.adUnit.autoRefill() {
                    SilverAd.shared.preloadAdWithAutoFill(adUnit: parent.adUnit)
                }
                SilverAdLog.d("CallbackDelegate.checkAutoReload -> \(parent.adUnit.adId) autoRefill=\(parent.adUnit.autoRefill())")
            }
        }
}

 
