// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SilverAd",
    
    platforms: [
        .iOS(.v17),      // 最低 iOS 13（根据需求调整）
//        .macOS(.v11)    // 可选：支持 Mac
    ],
    products: [
        .library(
            name: "SilverAd",
            targets: ["SilverAd"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/chengxiaoyu00/AppLovin-MAX-SDK-iOS.git", branch: "master"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SilverAd",
            dependencies: [
                .product(name: "AppLovinSDK", package : "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationGoogleAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationFacebookAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationMintegralAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationVungleAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationPangleAdapter", package: "AppLovin-MAX-SDK-iOS"),
                
                // Google Ads Adapter
                .product(name: "GoogleAppLovinAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "GoogleMintegralAdapterTarget", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "PangleAdapterTarget", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "MetaAdapterTarget", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "LiftoffMonetizeAdapterTarget", package: "AppLovin-MAX-SDK-iOS"),
                
            ],
            path: "Sources/ads",
            linkerSettings: [
                .linkedFramework("AdSupport"),
                .linkedFramework("AppTrackingTransparency"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("CoreTelephony"),
                .linkedFramework("Foundation"),
                .linkedFramework("MessageUI"),
                .linkedFramework("SafariServices"),
                .linkedFramework("StoreKit"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("UIKit"),
                .linkedFramework("WebKit"),
                .linkedLibrary("z"),
            ]
            
        ),

    ]
)
