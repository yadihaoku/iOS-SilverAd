
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
    @StateObject private var nativeViewModel = SilverNativeAdViewModel()

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
 

@MainActor
public class SilverNativeAdViewModel: ObservableObject {

    @Published
    public var nativeAd: ViewAd?

    public var callback: InteractionCallback?

    // 用于防止重复请求：持有当前正在执行的 Task
    private var fetchTask: Task<Void, Never>?

    public init(nativeAd: ViewAd? = nil, callback: InteractionCallback? = nil) {
        self.nativeAd = nativeAd
        self.callback = callback
    }
    
    public func destroy(){
        nativeAd?.destroy()
        nativeAd = nil
    }

    deinit {
        fetchTask?.cancel()
    }

    public func refreshAd(scene: String) {
        // 已有请求正在进行，忽略本次调用
        guard fetchTask == nil else {
            debugPrint("refreshAd: already fetching, skip")
            return
        }

        fetchTask = Task { [weak self] in
            defer {
                // 无论成功失败，结束后清空 task 引用，允许下次调用
                self?.fetchTask = nil
            }

            guard let ad = await SilverAd.shared.fetchViewAd(scene: scene) else {
                debugPrint("fetchViewAd failure!")
                return
            }

            // Task 被取消（deinit 触发）则不更新 UI
            guard !Task.isCancelled else { return }

            if let callback = self?.callback {
                ad.setAdCallback(callback)
            }

            self?.nativeAd?.destroy()
            self?.nativeAd = ad
        }
    }
}
// [END create_view_model]
