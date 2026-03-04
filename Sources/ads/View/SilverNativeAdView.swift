
import GoogleMobileAds
import SwiftUI

import UIKit

// [START add_view_model_to_view]
struct SilverNativeAdView: View {
    
    var scene       : String
    var minHeight   : CGFloat = 300
    var callback    : InteractionCallback? = nil
    // 无 @State 时 ，外层UI 刷新时，广告会丢失？？
    @State var nativeViewModel = AdMobNativeAdViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            
            if let viewAd = nativeViewModel.nativeAd{
                SilverAdBridgeView(viewAd: viewAd)
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
        .onDisappear{
            nativeViewModel.nativeAd?.destroy()
        }
    }

  private func refreshAd() {
      debugPrint("refresh ad")
      nativeViewModel.callback = callback
      nativeViewModel.refreshAd(scene: scene)
  }
}
 

@Observable
public class AdMobNativeAdViewModel {
    
    var nativeAd: ViewAd?
    @ObservationIgnored
    internal var callback: InteractionCallback?
    
    
    
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
