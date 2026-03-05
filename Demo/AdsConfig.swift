//
//  AdsConfig.swift
//  SceneSample
//
//  Created by yyd on 2026/2/26.
//  Copyright © 2026 Apple. All rights reserved.
//

/**
 开屏广告    ca-app-pub-3940256099942544/5575463023
 自适应横幅广告    ca-app-pub-3940256099942544/2435281174
 固定尺寸的横幅广告    ca-app-pub-3940256099942544/2934735716
 插页式广告    ca-app-pub-3940256099942544/4411468910
 激励广告    ca-app-pub-3940256099942544/1712485313
 插页式激励广告    ca-app-pub-3940256099942544/6978759866
 原生广告    ca-app-pub-3940256099942544/3986624511
 原生视频广告    ca-app-pub-3940256099942544/2521693316
 
 
 */



 
public enum TestAd: String, Codable {
    case banner             = "ca-app-pub-3940256099942544/2934735716"
    case native           = "ca-app-pub-3940256099942544/3986624511"      // Swift 中 native 是保留关键字，用 native_ 代替
    case interstitial       = "ca-app-pub-3940256099942544/4411468910"
    case reward             = "ca-app-pub-3940256099942544/1712485313"
    case reward_interstitial = "ca-app-pub-3940256099942544/6978759866"
    case app_open           = "ca-app-pub-3940256099942544/5575463023"
}
