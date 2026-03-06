
import GoogleMobileAds
import SwiftUI

import UIKit

// [START add_view_model_to_view]
public struct SilverNativeAdView : View {
    
    var scene       : String
    var minHeight   : CGFloat = 300
    var callback    : InteractionCallback? = nil
    var options     : ViewAdOptions? = nil
    
    // class ViewModel 用 @StateObject，struct 用 @State
    @StateObject private var nativeViewModel = AdMobNativeAdViewModel()

    public init(scene: String, minHeight: CGFloat = 300, callback: InteractionCallback? = nil, options: ViewAdOptions? = nil) {
        self.scene = scene
        self.minHeight = minHeight
        self.callback = callback
        self.options = options
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            
            if let viewAd = nativeViewModel.nativeAd{
                SilverAdBridgeView(viewAd: viewAd, options: options)
                    .id(viewAd.uuid)
                    .frame(minHeight: minHeight)
            }else{
                Text("NO ad")
            }
            
        }
        .opacity(nativeViewModel.nativeAd == nil ? 0 : 1)
        .onAppear {
            refreshAd()
        }
    }

  private func refreshAd() {
      guard nativeViewModel.nativeAd == nil else { return }
      
      nativeViewModel.callback = callback
      nativeViewModel.refreshAd(scene: scene)
       
  }
}
 

public class AdMobNativeAdViewModel: ObservableObject {
    
    @Published
    public var nativeAd: ViewAd?
    
    @ObservationIgnored
    public var callback: InteractionCallback?
    
    
    deinit {
        // 统一在这里销毁，生命周期和 ViewModel 绑定
        nativeAd?.destroy()
        nativeAd = nil
    }
    
    
    func refreshAd(scene : String) {
        
        Task{
            // 获取 ViewAd
            guard let ad = await SilverAd.shared.fetchViewAd(scene: scene) else{
                debugPrint("fetchViewAd failure!")
                return
            }
            // 设置 callback
            if let callback = self.callback{
                ad.setAdCallback(callback)
            }
            
            await MainActor.run {
                self.nativeAd?.destroy()
                self.nativeAd = ad
            }
        }
    }
}
// [END create_view_model]
