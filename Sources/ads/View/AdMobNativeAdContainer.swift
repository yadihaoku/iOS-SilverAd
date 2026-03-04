//
//  AdMobNativeAdContainer.swift
//  SceneSample
//
//  Created by yyd on 2026/3/2.
//  Copyright © 2026 Apple. All rights reserved.
//
import GoogleMobileAds
import SwiftUI

// [START create_native_ad_view]
struct AdMobAdLargeViewContainer: UIViewRepresentable {
  typealias UIViewType = NativeAdView

  @State var viewAd: ViewAd

  func makeUIView(context: Context) -> NativeAdView {
    
      SilverAdLog.d("SilverAdContainer NativeAdLargeViewContainer: makeUIView")
    return
      Bundle.main.loadNibNamed(
        "NativeAdView",
        owner: nil,
        options: nil)?.first as! NativeAdView
  }
    
    func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator){
        viewAd.destroy()
    }

  func updateUIView(_ nativeAdView: NativeAdView, context: Context) {
      SilverAdLog.d("SilverAdContainer NativeAdLargeViewContainer: updateUIView")
      guard let nativeAd = viewAd.originAd as? NativeAd else { return }

    // Each UI property is configurable using your native ad.
    (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline

    nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent

    (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body

    (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image

    (nativeAdView.starRatingView as? UIImageView)?.image = imageOfStars(from: nativeAd.starRating)

    (nativeAdView.storeView as? UILabel)?.text = nativeAd.store

    (nativeAdView.priceView as? UILabel)?.text = nativeAd.price

    (nativeAdView.advertiserView as? UILabel)?.text = nativeAd.advertiser

    (nativeAdView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)

    // For the SDK to process touch events properly, user interaction should be disabled.
    nativeAdView.callToActionView?.isUserInteractionEnabled = false

    // Associate the native ad view with the native ad object. This is required to make the ad
    // clickable.
    // Note: this should always be done after populating the ad views.
    nativeAdView.nativeAd = nativeAd
  }
  // [END create_native_ad_view]

  private func imageOfStars(from starRating: NSDecimalNumber?) -> UIImage? {
    guard let rating = starRating?.doubleValue else {
      return nil
    }
    if rating >= 5 {
      return UIImage(named: "stars_5")
    } else if rating >= 4.5 {
      return UIImage(named: "stars_4_5")
    } else if rating >= 4 {
      return UIImage(named: "stars_4")
    } else if rating >= 3.5 {
      return UIImage(named: "stars_3_5")
    } else {
      return nil
    }
  }
}
