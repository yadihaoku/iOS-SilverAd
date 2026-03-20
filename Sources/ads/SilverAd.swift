// SilverAd.swift
// Translated from SilverAd.kt (Kotlin object → Swift singleton class)
//
// 翻译说明：
// - Kotlin object          → Swift final class + static let shared
// - Kotlin CoroutineScope  → Swift structured concurrency (Task / actor)
// - ConcurrentHashMap      → Swift Dictionary + NSLock / actor 保护
// - Kotlin Mutex           → Swift actor 或 NSLock
// - AtomicBoolean          → Swift actor-isolated Bool 或 OSAtomicCompareAndSwapInt
// - WeakReference<Context> → Swift weak var (ARC 自动管理)
// - ProcessLifecycleOwner  → UIApplication foreground/background 通知

import Foundation
import UIKit
import GoogleMobileAds
import AppLovinSDK

// MARK: - AdLoadInterceptor

public protocol AdLoadInterceptor {
    /// 返回 true 表示拦截（不加载）
    func onIntercept(adUnit: AdUnit) -> Bool
    func onIntercept(scene: String) -> Bool
}

public struct DefaultRequestInterceptor: AdLoadInterceptor {
    public func onIntercept(adUnit: AdUnit) -> Bool { return false }
    public func onIntercept(scene: String) -> Bool { return false }
}

// MARK: - AdReporter（对应 Kotlin interface AdReporter）

// MARK: - SilverAdParams

public class SilverAdParams {
    public var debug: Bool = false
    public var reporter: AdReporter?
    public var loadInterceptor: AdLoadInterceptor?
    public var maxSdkKey: String?
    public var testIdentifiers: [String]?
    // Applovin Max sdk 需要 设置之后 会有一个 弹窗
    public var privacyPolicyURL: String?
    // Applovin Max sdk 需要 设置之后 会有一个 弹窗
    public var termsOfServiceURL: String?
    public var shouldShowTermsAndPrivacyPolicyAlertInGDPR = true
    
    public init(){}
}

// MARK: - SilverAd（主单例，对应 Kotlin object SilverAd）

public final class SilverAd {
    
    // MARK: - Singleton
    public static let shared = SilverAd()
    private init() { setupLifecycleObservers() }
    
    public static let STATE_ENABLED = 1
    
    private static let RETRY_LOAD_DELAY: TimeInterval = 30.0     // 秒
    private static let MIN_TIMEOUT: TimeInterval = 5.0
    private static let FETCH_AD_MAX_ATTEMPTS = 1
    private static let MAX_RETRY_COUNT = 3
    
    // MARK: - Config
    private var configInstance: AdConfig?
    public var currentConfig: AdConfig {
        return configInstance ?? .emptyConfig
    }
    
    // MARK: - Dependencies（可外部注入）
    private var limitManager = AdLimitManager.shared
    private var requestInterceptor: AdLoadInterceptor = DefaultRequestInterceptor()
    
    // MARK: - State
    private var isInitialized = false
    public var manualAllowAutoFill = true
    private var appIsInForeground = false {
        didSet {
            if !oldValue && self.appIsInForeground{
                self.scheduleStartupLoad()
            }
        }
    }
    // MARK: - Cache
    private let cacheManager = CacheManager()
    
    // MARK: - Retry
    private let stateLock = NSLock()
    private var retryTasks: [AdUnit: Task<Void, Never>] = [:]
    private var retryTimes: [AdUnit: Int] = [:]
    
    // MARK: - In-flight preload requests
//    private var preloadRequestList: [AdUnit: Task<Result<any Ad, Error>, Never>] = [:]
    private var preloadRequestList: [AdUnit: Task<Void, Never>] = [:]
    private let preloadLock = NSLock()
    
    private lazy var fetcher: AdFetcherOptimized = {
        AdFetcherOptimized(providers: [AdMobProvider(), MaxProvider()])
    }()
    
    // MARK: - JSON Decoder
    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private func updateAppState() {
        Task{@MainActor in
            let state = UIApplication.shared.applicationState
            appIsInForeground = (state == .active || state == .inactive)
            SilverAdLog.d("updateAppState appIsInForeground=\(appIsInForeground)")
        }
    }
    // MARK: - Lifecycle（替代 ProcessLifecycleOwner）
    
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        self.updateAppState()
    }
    
    @objc private func handleForeground() {
        SilverAdLog.d("handleForeground")
        appIsInForeground = true
    }
    
    @objc private func handleBackground() {
        SilverAdLog.d("handleBackground")
        appIsInForeground = false
    }
    
    // MARK: - Init
    public func initialize(params: SilverAdParams) {
        guard !isInitialized else {
            SilverAdLog.d("SilverAd: already initialized!")
            return
        }
        isInitialized = true
        SilverAdLog.isDebug = params.debug
        
        if let interceptor = params.loadInterceptor {
            requestInterceptor = interceptor
        }
        
        if let reporter = params.reporter {
            EventReporter.updateReporter(reporter)
        }
        
        // 走 Google UMP 逻辑
        if GDPRRegion.isCurrentRegionGDPR(){
            Task{
                await GoogleMobileAdsConsentManager.shared.gatherConsent(testIdentifiers: params.testIdentifiers ?? []) { error in
                    if GoogleMobileAdsConsentManager.shared.canRequestAds {
                        self.initAdSdk(params)
                        self.scheduleStartupLoad()
                    } else {
                        // 真正不能请求广告的情况：
                        // 用户是首次启动 + 在 EEA + 还未做出任何同意选择
                        // 此时必须等用户完成同意流程后才能展示广告（合规要求）
                        SilverAdLog.w("canRequestAds = false")
                        
                        if let error {
                            EventReporter.report(event: SilverAdEvent.initFailure) { extras in
                                extras["reason"] = error.localizedDescription
                            }
                        } else {
                            // 此时有异常
                            // 是否还能初始化 广告sdk，正常展示广告？？
                            EventReporter.report(event: SilverAdEvent.initFailure){extras in
                                extras["reason"] = "canRequestAds return false"
                            }
                        }
                    }
                }
            }
        } else {
            initAdSdk(params)
            scheduleStartupLoad()
        }
    }
    
    private func initAdSdk(_ params : SilverAdParams){
        
        debugPrint("initAdSdk ->\(params)")
        
        initMobileAds()
        initMax(params)
    }
    
    private func initMax(_ params : SilverAdParams){
        
        guard let key = params.maxSdkKey else{
            debugPrint("ignore init applovin max sdk")
            return
        }
        
        // Create the initialization configuration
        let initConfig = ALSdkInitializationConfiguration(sdkKey: key) { builder in
            
            builder.mediationProvider = ALMediationProviderMAX
            
            
            if params.debug{
                // Enable test mode by default for the current device.
                if let currentIDFV = UIDevice.current.identifierForVendor?.uuidString
                {
                    debugPrint("IDFV ->\(currentIDFV)")
                    builder.testDeviceAdvertisingIdentifiers = [currentIDFV]
                }
            }
        }
        
        // 2. 配置 SDK Settings（初始化前后均可设置）
        let settings = ALSdk.shared().settings
        // 开启日志输出
        settings.isVerboseLoggingEnabled = params.debug
        
        // 隐私服务设置
        // https://support.axon.ai/en/max/ios/overview/terms-and-privacy-policy-flow#enabling-max-terms-and-privacy-policy-flow
        if let privacyPolicyURL = params.privacyPolicyURL,let termsOfServiceURL = params.termsOfServiceURL {
            settings.termsAndPrivacyPolicyFlowSettings.isEnabled = true
            settings.termsAndPrivacyPolicyFlowSettings.privacyPolicyURL = URL(string: privacyPolicyURL)
            settings.termsAndPrivacyPolicyFlowSettings.termsOfServiceURL = URL(string: termsOfServiceURL)
        }
        // Showing Terms & Privacy Policy flow in GDPR region is optional (disabled by default)
        settings.termsAndPrivacyPolicyFlowSettings.shouldShowTermsAndPrivacyPolicyAlertInGDPR = params.shouldShowTermsAndPrivacyPolicyAlertInGDPR
        
        // Initialize the SDK with the configuration
        ALSdk.shared().initialize(with: initConfig) { sdkConfig in
            // AppLovin SDK is initialized, start loading ads now or later if ad gate is reached
            // Initialize Adjust SDK
            debugPrint("ALSdk inited!")
        }
        
    }
    
    private func initMobileAds(){
        MobileAds.shared.start(){a in
            debugPrint("MobileAds inited!")
        }
    }
    
    // MARK: - Config Update
    
    public func updateConfig(jsonString: String) {
        do {
            guard let data = jsonString.data(using: .utf8) else { return }
            let config = try decoder.decode(AdConfig.self, from: data)
            updateConfig(config)
        } catch {
            EventReporter.report(event: SilverAdEvent.adConfigUpdate){extras in
                extras[SilverAdEvent.Param.result] = false
                extras[SilverAdEvent.Param.reason] = error.localizedDescription
            }
            SilverAdLog.w("updateConfig decode error: \(error)")
        }
    }
    
    public func updateConfig(_ adConfig: AdConfig) {
        let curVersion = currentConfig.version
//        guard adConfig.version > curVersion else {
//            SilverAdLog.d("updateConfig ignored: new=\(adConfig.version) cur=\(curVersion)")
//            return
//        }
        SilverAdLog.d("updateConfig ignored: new=\(adConfig.version) cur=\(curVersion)")
        configInstance = adConfig
        
        EventReporter.report(event: SilverAdEvent.adConfigUpdate){extras in
            extras[SilverAdEvent.Param.result] = true
            extras[SilverAdEvent.Param.newVersion] = adConfig.version
            extras[SilverAdEvent.Param.oldVersion] = curVersion
        }
        
        // 取消所有 retry 任务
        stateLock.withLock {
            retryTasks.values.forEach { $0.cancel() }
            retryTasks.removeAll()
            retryTimes.removeAll()
        }
        
        Task { await MainActor.run { scheduleStartupLoad() } }
    }
    
    // MARK: - Can Show Ad
    
    public func canShowAd(scene: String) -> Bool {
        return canShowAdInternal(scene: scene).0
    }
    
    public func canShowAd(scene: String, reportMsg: Bool = false) -> (Bool, AdShowFailReason) {
        let checkResult = canShowAdInternal(scene: scene)
        
        if reportMsg && !checkResult.0{
            EventReporter.report(event: SilverAdEvent.adShowCheck){extras in
                extras[SilverAdEvent.Param.result] = false
                extras[SilverAdEvent.Param.scene] = scene
                extras[SilverAdEvent.Param.reason] = checkResult.1.rawValue
                extras[SilverAdEvent.Param.configVersion] = currentConfig.version
            }
        }
        return checkResult
    }
    
    private func canShowAdInternal(scene: String) -> (Bool, AdShowFailReason) {
        
        guard isInitialized else{
            SilverAdLog.w("canShowAd: [\(scene)] -> false. sdk not init.")
            return (false, .sdkNotInit)
        }
        
        let config = currentConfig

        guard config.isEnabled() else {
            SilverAdLog.w("canShowAd: [\(scene)] -> false. ad config is disabled.")
            return (false, .adConfigDisabled)
        }
        
        guard let adScene = config.findAdScene(scene) else {
            SilverAdLog.w("canShowAd: [\(scene)] -> false. scene not found.")
            return (false, .sceneNotMatch)
        }
        
        guard adScene.isEnabled() else{
            SilverAdLog.w("canShowAd: [\(scene)] -> false. scene disabled.")
            return (false, .sceneDisabled)
        }
        
        let adUnits = getEnabledAdUnits(scene: scene)
        guard !adUnits.isEmpty, let firstUnit = adUnits.first else {
            SilverAdLog.w("canShowAd: [\(scene)] -> false. no enabled adUnits.")
            return (false, .adUnitNotFound)
        }
        let todayLimit = isOverTodayAdLimit()
        if todayLimit != .none{
            return (false, todayLimit)
        }
        
        let adTypeLimit = isOverTodayAdTypeLimit(for: firstUnit.type)
        if adTypeLimit != .none{
            return (false, adTypeLimit)
        }
        
        
        if requestInterceptor.onIntercept(scene: scene) {
            return (false, .blockByInterceptor)
        }
        
        
        return  (true, .none)
    }
    
    public func isOverTodayAdLimit() -> AdShowFailReason {
        let count = limitManager.getAdClickCount()
        let limit = currentConfig.clickLimit
        if count >= limit && limit > 0 {
            SilverAdLog.d("canShowAd-> false. over click limit. (\(count) >= \(limit))")
            return .clickLimit
        }
        return .none
    }
    
    public func isOverTodayAdTypeLimit(for type : AdFormat) -> AdShowFailReason {
        
        let limits = currentConfig.adLimits.config(for: type)
        
        let adTypeStat = limitManager.getAdTypeStat(type: type)
        
        let showCountForType = adTypeStat.showCount
        if limits.daily24hShowLimit > 0 && showCountForType >= limits.daily24hShowLimit {
            SilverAdLog.d("canShowAd-> false. over daily24hShowLimit limit. (\(showCountForType) >= \(limits.daily24hShowLimit))")
            return .showLimit
        }
        
        let clickCountForType = adTypeStat.clickCount
        if limits.daily24hClickLimit > 0 && clickCountForType >= limits.daily24hClickLimit {
            SilverAdLog.d("canShowAd-> false. over daily24hClickLimit limit. (\(clickCountForType) >= \(limits.daily24hClickLimit))")
            return .clickLimit
        }
        
        let singleAdStat = limitManager.getSingleAdStat()
        
        let overLimtType = AdFormat.allCases.first { t in
            
            let adTypeLimit = currentConfig.adLimits.config(for: t)
            
            let clickCountForSingleAd = singleAdStat[t] ?? 0
            
            if adTypeLimit.singleAdClickLimit > 0 && clickCountForSingleAd >= adTypeLimit.singleAdClickLimit {
                SilverAdLog.d("canShowAd-> false. over singleAdClickLimit limit. (\(clickCountForSingleAd) >= \(adTypeLimit.singleAdClickLimit))")
                return true
            }
            return false
        }
        
        if overLimtType != nil{
            return .singleAdClickLimit
        }
        
        
        return .none
    }
    
    public func incrementAdIntervalLimit(scene: String) {
        limitManager.incrementAdLimitCount(scene: scene)
    }
    
    // MARK: - Fetch Ad（对应 Kotlin suspend fun fetchAd）
    
    public func fetchFullScreenAd(scene: String, waitIfNotReady: Bool = true) async -> (any FullScreenAd)? {
        return await fetchAd(scene: scene, waitIfNotReady: waitIfNotReady) as? (any FullScreenAd)
    }
    
    public func fetchViewAd(scene: String, waitIfNotReady: Bool = true) async -> (any ViewAd)? {
        return await fetchAd(scene: scene, waitIfNotReady: waitIfNotReady) as? (any ViewAd)
    }
    
    private func fetchAd(scene: String, waitIfNotReady: Bool) async -> (any Ad)? {
        let check = canShowAdInternal(scene: scene)
        guard check.0, let adScene = currentConfig.findAdScene(scene) else {
            SilverAdLog.w("fetchAd: blocked. scene=\(scene) reason=\(check.1)")
            
            EventReporter.report(event: SilverAdEvent.adFetchResult, extras : [
                SilverAdEvent.Param.scene : scene,
                SilverAdEvent.Param.result : false,
                SilverAdEvent.Param.reason : check.1.rawValue,
                SilverAdEvent.Param.configVersion : currentConfig.version
            ])
            
            return nil
        }
        
        debugPrint("fetchAd: scene -> \(scene)")
        // 先查缓存
        if let cached = retrieveCachedAd(scene: scene) {
            cached.currentAdScene = adScene
            // 触发自动填充预加载
            let autoRefillUnits = getEnabledAdUnits(scene: scene).filter { $0.autoRefill() }
            preloadAdByUnits(adUnits: autoRefillUnits)
            
            let eventData  = (cached as? BaseAd)?.buildEventData()
            EventReporter.report(event: SilverAdEvent.adFetchResult,eventData: eventData, extras : [
                SilverAdEvent.Param.result : true,
                SilverAdEvent.Param.from : "cache",
            ])
            
            return cached
        }
        
        guard waitIfNotReady else { return nil }
        
        // 实时加载最快的广告
        let result = await fastestAdByScene(adScene: adScene)
        
        var ad : Ad?
        var reportParams : [String : Any] = [
            SilverAdEvent.Param.scene : scene,
            SilverAdEvent.Param.from : "load",
        ]
        do{
            ad = try result.get()
            ad?.currentAdScene = adScene
        }catch{
            if let loadError = error as? AdLoadException{
                debugPrint("fastestAd failure: \(String(describing: loadError.errorDescription))")
                reportParams[SilverAdEvent.Param.reason] = loadError.errorDescription
            }else{
                reportParams[SilverAdEvent.Param.reason] = String(describing:  error)
            }
            debugPrint("fastestAd failure: \(error)")
        }
        reportParams[SilverAdEvent.Param.result] = ad != nil
        
        let eventData  = (ad as? BaseAd)?.buildEventData()
        EventReporter.report(event: SilverAdEvent.adFetchResult,eventData: eventData, extras :reportParams)
        
        return ad
    }
    
    // MARK: - Preload
    
    public func preloadAd(scene: String) {
        guard canShowAd(scene: scene) else { return }
        let adUnits = getEnabledAdUnits(scene: scene).filter { !cacheManager.isCachedByAdUnit($0) }
        guard !adUnits.isEmpty else { return }
        preloadAdByUnits(adUnits: adUnits)
    }
    
    private func preloadAdByUnits(adUnits: [AdUnit]) {
        Task {
            for unit in adUnits {
                preloadAd(adUnit: unit)
            }
        }
    }
    
    private func preloadAd(adUnit: AdUnit) {
        guard canPreloadAd(adUnit: adUnit) else {
            SilverAdLog.d("canPreloadAd: false ->\(adUnit.desc())")
            return
        }

        preloadLock.withLock {
            guard preloadRequestList[adUnit] == nil else {
                return
            }
            
            // 用 placeholder 占位，防止竞态窗口
            let task = Task {
                await loadAndCacheAdByUnit(adUnit: adUnit)
                preloadLock.withLock {
                    preloadRequestList.removeValue(forKey: adUnit)
                }
            }
            preloadRequestList[adUnit] = task
        }
    }
    
    internal func preloadAdWithAutoFill(adUnit: AdUnit) {
        guard manualAllowAutoFill else {
            SilverAdLog.w("preloadAdWithAutoFill cancel! allowAutoFill=false")
            return
        }
        guard canPreloadAd(adUnit: adUnit) else { return }
        Task {
            if adUnit.autoFill > 0 {
                try? await Task.sleep(nanoseconds: UInt64(adUnit.autoFill * 1_000_000_000))
            }
            await loadAndCacheAdByUnit(adUnit: adUnit)
        }
    }
    
    private func canPreloadAd(adUnit: AdUnit) -> Bool {
        if !currentConfig.isEnabled(){ return false }
        if isOverTodayAdLimit() != .none  { return false }
        if isOverTodayAdTypeLimit(for: adUnit.type) != .none  { return false }
        
        // 这行代码有异常 Task 6: EXC_BAD_ACCESS (code=1, address=0x10)
        let isPreloading = preloadLock.withLock {
            preloadRequestList[adUnit] != nil
        }
        if isPreloading {
            SilverAdLog.d("\(adUnit) in preload preloadRequestList")
            return false
        }
        
        if cacheManager.isCachedByAdUnit(adUnit) { return false }
        if requestInterceptor.onIntercept(adUnit: adUnit) { return false }
        if !appIsInForeground {
            SilverAdLog.d("appIsInForeground  false")
            return false
        }
        return true
    }
    
    // MARK: - Load & Cache
    
    private func loadAndCacheAdByUnit(adUnit: AdUnit) async {
        let result = await performFetch(adUnit: adUnit)
        handleCompletedAd(unit: adUnit, result: result)
    }
    
    private func performFetch(adUnit: AdUnit) async -> Result<any Ad, Error> {
        return await AdRequestLimiter.withGlobalPermit(adUnit: adUnit) {
            await performFetchInternal(adUnit: adUnit)
        }
    }
    
    private func performFetchInternal(adUnit: AdUnit) async -> Result<any Ad, Error> {
        
        var attempt = 0
        var backoff: UInt64 = 500_000_000  // 0.5s in nanoseconds
        
        while attempt < SilverAd.FETCH_AD_MAX_ATTEMPTS {
            let res = await fetcher.fetch(adUnit: adUnit)
            if case .success = res { return res }
            attempt += 1
            if attempt < SilverAd.FETCH_AD_MAX_ATTEMPTS {
                try? await Task.sleep(nanoseconds: backoff)
                backoff = min(backoff * 2, 2_000_000_000)
            } else {
                return res
            }
        }
        return .failure(AdLoadException(code: AdLoadException.CODE_OTHER, msg: "performFetch: all attempts failed"))
    }
    
    private func handleCompletedAd(unit: AdUnit, result: Result<any Ad, Error>) {
        switch result {
        case .success(let ad):
            if ad.isReady() {
                cacheManager.enqueueCache(ad)
                SilverAdLog.w("handleCompletedAd: enqueued to cache -> \(ad)")
            } else {
                scheduleRetry(adUnit: unit)
            }
        case .failure(let error):
            if let loadErr = error as? AdLoadException, loadErr.code == AdLoadException.CODE_IN_OTHER_TASK {
                SilverAdLog.w("handleCompletedAd: skip retry (in other task)")
                return
            }
            scheduleRetry(adUnit: unit)
        }
    }
    
    // MARK: - Fastest Ad（并行加载，返回最快成功的广告，其余继续加载后入缓存）
        //
        // 架构设计：
        //
        //   ┌─ Task(A) performFetch ─┐
        //   ├─ Task(B) performFetch ─┤──yield──▶ AsyncStream ──▶ 后台消费 Task
        //   └─ Task(C) performFetch ─┘                │
        //                                             │ 同时
        //                                        firstResultCont（CheckedContinuation）
        //                                             │ 第一个成功/全部失败 → resume 一次
        //                                             ▼
        //                                        调用方拿到结果立即返回
        //                                        后台消费 Task 继续处理剩余结果
        //
        // 关键：加载 Task、stream 消费、超时 三者完全解耦
        //   - 加载 Task 不受主流程取消影响
        //   - 超时只影响调用方等待，不取消任何 Task
        //   - stream 消费 Task 独立运行到所有结果收齐为止

        private func fastestAdByScene(adScene: AdScene) async -> Result<any Ad, Error> {
            let adUnits = getEnabledAdUnits(scene: adScene.sceneName)
            guard !adUnits.isEmpty else {
                return .failure(AdLoadException(code: "-1", msg: "no ad units for scene \(adScene.sceneName)"))
            }

            let timeout = max(adScene.waitDuration / 1000, SilverAd.MIN_TIMEOUT)
            let totalCount = adUnits.count

            // stream：所有加载结果的汇聚通道
            let (stream, continuation) = AsyncStream<(AdUnit, Result<any Ad, Error>)>
                .makeStream(bufferingPolicy: .unbounded)

            // 用 actor 保证 firstResultCont 只被 resume 一次（多个 Task 并发竞争）
            let racer = FirstResultRacer()

            // ── 第一步：启动所有加载 Task（独立，不受主流程取消影响）──
            for unit in adUnits {
                Task { [weak self] in
                    if let self {
                        let result = await self.performFetch(adUnit: unit)
                        continuation.yield((unit, result))
                    } else {
                        continuation.yield((unit, .failure(
                            AdLoadException(code: "-1", msg: "SilverAd released")
                        )))
                    }
                }
            }

            // ── 第二步：启动后台消费 Task（独立，消费所有 totalCount 条结果）──
            Task { [weak self] in
                var receivedCount = 0
                var hasFirstSuccess = false

                for await (unit, result) in stream {
                    receivedCount += 1

                    switch result {
                    case .success(let ad):
                        let isFirst = await racer.trySetFirst(ad)
                        if isFirst {
                            // 第一个成功：通知调用方
                            hasFirstSuccess = true
                            SilverAdLog.d("fastestAdByScene: first success \(unit.adId)")
                        } else {
                            // 后续成功：入缓存
                            SilverAdLog.d("fastestAdByScene: extra success, cache \(unit.adId)")
                            self?.cacheManager.enqueueCache(ad)
                        }

                    case .failure(let err):
                        SilverAdLog.d("fastestAdByScene: failed \(unit.adId)")
                        // 全部失败时通知调用方
                        if receivedCount == totalCount && !hasFirstSuccess {
                            await racer.failIfNeeded(err)
                        } else {
                            self?.scheduleRetry(adUnit: unit)
                        }
                    }

                    // 所有结果收齐，结束 stream
                    if receivedCount == totalCount {
                        continuation.finish()
                        break
                    }
                }
            }

            // ── 第三步：等待第一个结果，带超时 ──
            return await withTaskGroup(of: Result<any Ad, Error>.self) { group in

                // 等待 racer 给出结果
                group.addTask {
                    await racer.wait()
                }

                // 超时任务：到期后强制返回失败（不取消加载 Task，不影响后台消费）
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    await racer.timeoutIfNeeded(
                        AdLoadException(code: "-1", msg: "timeout for scene \(adScene.sceneName)")
                    )
                    return await racer.wait()
                }

                let result = await group.next() ?? .failure(
                    AdLoadException(code: "-1", msg: "race group empty")
                )
                group.cancelAll()
                return result
            }
        }
    
    // MARK: - Retry
    
    
    private func scheduleRetry(adUnit: AdUnit) {
        var shouldSchedule = false

        stateLock.withLock {
            let count = (retryTimes[adUnit] ?? 0) + 1
            retryTimes[adUnit] = count

            guard count <= SilverAd.MAX_RETRY_COUNT else {
                SilverAdLog.w("scheduleRetry: over max retry count!! \(adUnit)")
                retryTasks.removeValue(forKey: adUnit)?.cancel()
                retryTimes.removeValue(forKey: adUnit)
                return
            }

            guard retryTasks[adUnit] == nil else {
                return
            }

            shouldSchedule = true
        }

        guard shouldSchedule else { return }

        // Task 创建放在锁外
        let task = Task {
            defer{
                self.stateLock.withLock {
                    self.retryTasks.removeValue(forKey: adUnit)
                }
            }
            
            try? await Task.sleep(nanoseconds: UInt64(SilverAd.RETRY_LOAD_DELAY * 1_000_000_000))
            self.preloadAd(adUnit: adUnit)
        }

        stateLock.withLock {
            retryTasks[adUnit] = task
        }
    }
    
    public func cancelRetry(adUnit: AdUnit) {
        stateLock.withLock {
            retryTasks.removeValue(forKey: adUnit)?.cancel()
            retryTimes.removeValue(forKey: adUnit)
        }
    }
    
    // MARK: - Startup Load
    
    private func scheduleStartupLoad() {
        let config = currentConfig
        guard isInitialized, !config.adPools.isEmpty else {
            SilverAdLog.w("scheduleStartupLoad: skipped")
            return
        }
        guard manualAllowAutoFill else { return }
        
        let adUnits = config.findAllStartLoadUnits()
        guard !adUnits.isEmpty else { return }
        preloadAdByUnits(adUnits: adUnits)
    }
    
    // MARK: - Cache Access
    
    internal func retrieveCachedAd(adUnit: AdUnit) -> (any Ad)? {
        return cacheManager.pickAd(for: adUnit)
    }
    
    private func retrieveCachedAd(scene: String) -> (any Ad)? {
        let units = getEnabledAdUnits(scene: scene)
        return cacheManager.pickAd(matching: units)
    }
    
    internal func enqueueCache(_ ad: any Ad) {
        cacheManager.enqueueCache(ad)
    }
    
    internal func dequeueCache(_ ad: any Ad) {
        cacheManager.removeCachedAd(ad)
    }
    
    // MARK: - Helpers
    
    private func getEnabledAdUnits(scene: String) -> [AdUnit] {
        return currentConfig.findAdUnitByScene(scene)
            .filter { $0.state == SilverAd.STATE_ENABLED }
            .uniqued()
    }
    
    // MARK: - Destroy
    
    public func destroyAd(scene: String) {
        currentConfig.findAdUnitByScene(scene).forEach {
            cacheManager.destroyCachedAd(adUnit: $0)
        }
    }
    
    public func destroyAll() {
        cacheManager.destroyAll()
    }
}

// MARK: - Array Unique Helper（替代 Kotlin .distinct()）

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}


// MARK: - FirstResultRacer
//
// actor 保证并发安全：多个加载 Task 同时完成时，只有第一个 resume continuation
// 后续的 trySetFirst 返回 false，调用方直接走入缓存逻辑
private actor FirstResultRacer {

    private var continuation: CheckedContinuation<Result<any Ad, Error>, Never>?
    private var resolvedResult: Result<any Ad, Error>? = nil  // 存结果，替代 Bool 标志

    // MARK: - wait

    func wait() async -> Result<any Ad, Error> {
        // 已有结果（trySetFirst 比 wait 先执行），直接返回，不挂起
        if let result = resolvedResult {
            return result
        }

        return await withCheckedContinuation { cont in
            // double-check：进入 continuation 前再检查一次（actor 重入保护）
            if let result = resolvedResult {
                cont.resume(returning: result)
            } else {
                continuation = cont
            }
        }
    }

    // MARK: - trySetFirst

    @discardableResult
    func trySetFirst(_ ad: any Ad) -> Bool {
        guard resolvedResult == nil else { return false }
        resolve(with: .success(ad))
        return true
    }

    // MARK: - failIfNeeded

    func failIfNeeded(_ error: Error) {
        guard resolvedResult == nil else { return }
        resolve(with: .failure(error))
    }

    // MARK: - timeoutIfNeeded

    func timeoutIfNeeded(_ error: Error) {
        guard resolvedResult == nil else { return }
        resolve(with: .failure(error))
    }

    // MARK: - 统一 resolve 入口

    private func resolve(with result: Result<any Ad, Error>) {
        resolvedResult = result          // 先存结果
        continuation?.resume(returning: result)
        continuation = nil
    }
}
