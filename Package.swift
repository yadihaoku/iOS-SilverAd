// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "iOS-SilverAd",
    
    // 🔹 支持的平台（iOS 库必备）
    platforms: [
        .iOS(.v17),      // 最低 iOS 13（根据需求调整）
        .macOS(.v11)    // 可选：支持 Mac
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "iOS-SilverAd",
            targets: ["ads"]
        ),
    ],
    dependencies: [
        //
        .package(url: "https://github.com/chengxiaoyu00/AppLovin-MAX-SDK-iOS.git", branch: "master"),
//        .package(url: "https://github.com/facebook/FBAudienceNetwork.git", .upToNextMajor(from: "6.21.1")),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", .upToNextMajor(from: "13.1.0")),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ads",
            dependencies: [
                .product(name: "AppLovinSDK", package : "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationGoogleAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationFacebookAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationVungleAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationMintegralAdapter", package: "AppLovin-MAX-SDK-iOS"),
                .product(name: "AppLovinMediationInMobiAdapter", package: "AppLovin-MAX-SDK-iOS"),
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

// swift-tools-version: 5.9
// ⚠️ 声明最低 Swift 版本，影响可用特性
/*
import PackageDescription

let package = Package(
    // 🔹 包名称（发布到 GitHub 时需与仓库名一致）
    name: "MyLibrary",
    
    // 🔹 支持的平台（iOS 库必备）
    platforms: [
        .iOS(.v13),      // 最低 iOS 13（根据需求调整）
        .macOS(.v11),    // 可选：支持 Mac
        .tvOS(.v13),     // 可选：支持 tvOS
        .watchOS(.v6),   // 可选：支持 watchOS
    ],
    
    // 🔹 产品定义：库的对外接口
    products: [
        // 库产品：其他项目可依赖此 target
        .library(
            name: "MyLibrary",
            targets: ["MyLibrary"]
        ),
        // 如果需要动态库（罕见场景）
        // .library(name: "MyLibrary", type: .dynamic, targets: ["MyLibrary"])
    ],
    
    // 🔹 依赖项：第三方库
    dependencies: [
        // ✅ 示例 1: 依赖另一个 SPM 包（远程 Git）
        .package(
            url: "https://github.com/Alamofire/Alamofire.git",
            .upToNextMajor(from: "5.8.0")
        ),
        
        // ✅ 示例 2: 依赖特定版本范围
        .package(
            url: "https://github.com/SnapKit/SnapKit.git",
            .upToNextMinor(from: "5.6.0")
        ),
        
        // ✅ 示例 3: 依赖二进制框架（.xcframework）
        .package(
            url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git",
            .upToNextMajor(from: "13.6.0")
        ),
        
        // ✅ 示例 4: 本地路径依赖（开发调试用）
        // .package(path: "../LocalDependency"),
        
        // ✅ 示例 5: 精确版本（不推荐，除非必要）
        // .package(url: "...", exact: "1.2.3"),
    ],
    
    // 🔹 Target 定义：源码 + 依赖 + 配置
    targets: [
        // 🎯 主库 Target
        .target(
            name: "MyLibrary",
            dependencies: [
                // 引用上方 dependencies 中的产品
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            path: "Sources/MyLibrary",  // 源码路径（默认可省略）
            
            // 🔹 资源文件（图片、xib、json 等）
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),  // iOS 14+ 隐私清单
                .process("Resources/Assets.xcassets"),     // 资产目录
            ],
            
            // 🔹 编译设置
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .enableExperimentalFeature("StrictConcurrency"),  // Swift 6 并发检查
            ],
            linkerSettings: [
                .linkedFramework("UIKit"),      // 链接系统框架
                .linkedFramework("Foundation"),
                .linkedLibrary("z"),            // 链接系统库
            ]
        ),
        
        // 🧪 单元测试 Target
        .testTarget(
            name: "MyLibraryTests",
            dependencies: ["MyLibrary"],  // 依赖主库
            path: "Tests/MyLibraryTests",
            resources: [
                .copy("TestData/sample.json"),  // 测试资源
            ]
        ),
        
        // 🎬 UI 测试 Target（可选）
        .testTarget(
            name: "MyLibraryUITests",
            dependencies: ["MyLibrary"],
            path: "Tests/MyLibraryUITests"
        ),
    ],
    
    // 🔹 Swift 包注册表（未来发布用）
    registries: [
        .packageRegistry("https://packages.example.com")  // 私有注册表
    ]
)
*/
