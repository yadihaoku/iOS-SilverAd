//
//  MaxAdNativeAdContainer.swift
//  SceneSample
//
//  Created by yyd on 2026/3/2.
//  Copyright © 2026 Apple. All rights reserved.
//

import SwiftUI
import AppLovinSDK

// [START create_native_ad_view]
struct MaxAdLargeViewContainer: UIViewRepresentable {
    typealias UIViewType = MANativeAdView
    
    private var viewAd: ViewAd
    
    func makeUIView(context: Context) -> MANativeAdView {
        debugPrint("SilverAdContainer MaxAdLargeViewContainer ->makeUIView")
        return viewAd.asView(options: nil) as! MANativeAdView
    }
    
    func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator){
        viewAd.destroy()
    }
    
    func updateUIView(_ nativeAdView: MANativeAdView, context: Context) {
        debugPrint("SilverAdContainer MaxAdLargeViewContainer ->updateUIView")
    }
}


public struct SilverAdBridgeView: UIViewRepresentable {
    
    public typealias UIViewType = UIView
    
    var viewAd: ViewAd
    var options: ViewAdOptions? = nil
    
    init(viewAd: ViewAd, options: ViewAdOptions? = nil) {
        self.viewAd = viewAd
        self.options = options
    }
    
    public func makeUIView(context: Context) -> UIView {
        debugPrint("SilverAdContainer  ->makeUIView \(viewAd.uuid)")
        return viewAd.asView(options: options)!
    }
    
    func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator){
        debugPrint("SilverAdContainer  ->dismantleUIView \(viewAd.uuid)")
        viewAd.destroy()
    }
    
    public func updateUIView(_ nativeAdView: UIView,context: Context) {
        debugPrint("SilverAdContainer  ->updateUIView \(viewAd.uuid)")
    }
}
