//
//  AdsContent.swift
//  SceneSample
//
//  Created by yyd on 2026/2/26.
//  Copyright © 2026 Apple. All rights reserved.
//

import SwiftUI

class FSADViewModel: NSObject, ObservableObject{
    
    
    var fsAd : FullScreenAd?
    
    var rewardAd : FullScreenAd?
    
    private lazy var adCllback = RewardAdCllback()
    
    func showAd(){
        Task{
            fsAd = await SilverAd.shared.fetchFullScreenAd(scene: "scene1")
            debugPrint("loadAd \(String(describing: fsAd))")
                await fsAd?.show(from: nil)
        }
    }
    
    func showReward(){
        Task{
            rewardAd = await SilverAd.shared.fetchFullScreenAd(scene: "reward")
            
            guard let rewardAd = rewardAd else{
                return
            }
            
            rewardAd.setAdCallback(adCllback)
            
            await rewardAd.show(from: nil)
        }
    }
}

private class RewardAdCllback :InteractionCallback{
    func onAdClicked() {
        debugPrint("\(#function) called!!")
    }
    
    func onAdClosed() {
        debugPrint("\(#function) called!!")
    }
    
    func onAdShowed() {
        debugPrint("\(#function) called!!")
    }
    
    func onAdImpression() {
        debugPrint("\(#function) called!!")
    }
    
    func onAdsPaid() {
        debugPrint("\(#function) called!!")
    }
}

private class NatvieAdCallback : InteractionCallback{
    func onAdClicked() {
        
    }
    
    func onAdClosed() {
        
    }
    
    func onAdShowed() {
        debugPrint("nativeAd show")
    }
    
    func onAdImpression() {
        
    }
    
    func onAdsPaid() {
        
    }
    
    
}


struct AdListContentView: View {
    @State private var items = ["🍎 Apple", "🍌 Banana", "🍇 Grape", "🍊 Orange"]
    @State private var deletingItems = Set<String>() // 记录正在删除的行
    
    @State var model = FSADViewModel()
    
    @State var adModel = AdMobNativeAdViewModel()
    
    private var callback = NatvieAdCallback()
    
    var body: some View {
        NavigationView {
            
            ScrollView{
                
                VStack(spacing: 12){
                    Button("Reset UMP"){
                        GoogleMobileAdsConsentManager.shared.reset()
                    }
                    .padding(.all, 8)
                    .foregroundColor(Color.white)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                    .background(Capsule(style: .continuous))
                    Button("ATT"){
                        ATTracker.shared.request()
                    }
                    
                    Button("App open ad"){
                        AppOpenAdManager.shared.showAdIfAvailable()
                    }
                    
                    Button("Interstitial"){
                        model.showAd()
                    }
                    
                    Button("Reward"){
                        model.showReward()
                    }
                    SilverNativeAdView(scene: "content", callback: callback)
                    
                    Button("refresh new native Ad"){
                        adModel.refreshAd(scene: "content")
                    }
                    if let ad = adModel.nativeAd{
                        SilverAdBridgeView(viewAd: ad)
                            .id(ad.uuid)
                            .frame(minHeight: 300)
                    }
                }
                
               
//                SilverNativeAdView()
            }
        }
    }
}
