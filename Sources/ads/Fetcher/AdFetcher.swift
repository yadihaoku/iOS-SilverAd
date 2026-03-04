// AdFetcher.swift
// Translated from AdFetcher.kt + AdFetcherOptimized.kt
//
// 翻译说明：
// - Kotlin open class AdFetcher          →  Swift class AdFetcher（open by default in module）
// - Kotlin suspend fun fetch/doFetch     →  Swift async throws func
// - Kotlin Result<Ad>                    →  Swift Result<Ad, Error>
// - Kotlin providers.associateBy { it.name } → Dictionary(uniqueKeysWithValues:)
// - Kotlin System.currentTimeMillis()    →  CFAbsoluteTimeGetCurrent()（秒，精度足够）
// - Android Context 参数                 →  iOS 无对应概念，直接移除
// - AdFetcherOptimized 合并在同一文件

import Foundation

// MARK: - AdFetcher

class AdFetcher {

    private let providers: [AdProvider]

    // 对应 Kotlin providerMapping by lazy { providers.associateBy { it.name } }
    private lazy var providerMapping: [String: AdProvider] = {
        Dictionary(uniqueKeysWithValues: providers.map { ($0.name, $0) })
    }()

    init(providers: [AdProvider]) {
        self.providers = providers
    }

    // MARK: - 单次获取一条广告（对应 Kotlin suspend fun fetch）

    func fetch(adUnit: AdUnit) async -> Result<Ad, Error> {
        SilverAdLog.d("Fetch: start -> (\(adUnit))")

        guard let provider = providerMapping[adUnit.platform] else {
            return .failure(AdLoadException(
                code: AdLoadException.CODE_NOT_MATCH_PROVIDER,
                msg: "No provider found for platform: \(adUnit.platform)"
            ))
        }

        return await AdRequestLimiter.withPermit(adUnit: adUnit) {
            await self.doFetch(provider: provider, adUnit: adUnit)
        }
    }

    // MARK: - 实际加载（子类可 override，对应 Kotlin open suspend fun doFetch）

    func doFetch(provider: AdProvider, adUnit: AdUnit) async -> Result<Ad, Error> {
        let loadStart = CFAbsoluteTimeGetCurrent()
        let ad = await provider.createAd(adUnit: adUnit)
        let loadResult = await ad.load()
        let usedMs = Int((CFAbsoluteTimeGetCurrent() - loadStart) * 1000)

        // 对应 Kotlin: if (loadResult.isSuccess) ... else ...
        // Swift Result<Bool, Error>：成功时还需确认 Bool 值为 true
        switch loadResult {
        case .success(let loaded) where loaded:
            SilverAdLog.d("FetchAd: success -> \(adUnit.name):\(adUnit.adId) usedTime=\(usedMs)ms (\(adUnit))")
            return .success(ad)
        case .success:
            // load() 返回 true=false，视为失败（对应 Kotlin Result.failure）
            let error = AdLoadException(code: AdLoadException.CODE_SDK_ERROR, msg: "ad.load() returned false")
            SilverAdLog.d("FetchAd: failure -> \(adUnit.name):\(adUnit.adId) usedTime=\(usedMs)ms\n\(error)\n(\(adUnit))")
            return .failure(error)
        case .failure(let error):
            // 对应 Kotlin: loadResult.exceptionOrNull() ?: AdLoadException.UNKNOWN_ERROR
            SilverAdLog.d("FetchAd: failure -> \(adUnit.name):\(adUnit.adId) usedTime=\(usedMs)ms\n\(error)\n(\(adUnit))")
            return .failure(error)
        }
    }
}

// MARK: - AdFetcherOptimized（对应 Kotlin class AdFetcherOptimized : AdFetcher）
//
// 优化策略：先查内存缓存，命中则直接返回，不发起网络请求

final class AdFetcherOptimized: AdFetcher {

    override func doFetch(provider: AdProvider, adUnit: AdUnit) async -> Result<Ad, Error> {
        // 先尝试从缓存取（对应 Kotlin SilverAd.retrieveCachedAd(adUnit)）
        if let cachedAd = SilverAd.shared.retrieveCachedAd(adUnit: adUnit) {
            SilverAdLog.w("AdFetcherOptimized: fetch ad from cache! \(cachedAd)")
            return .success(cachedAd)
        }
        // 缓存未命中，走正常加载流程
        return await super.doFetch(provider: provider, adUnit: adUnit)
    }
}
