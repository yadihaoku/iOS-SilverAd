//
//  Copyright (C) 2023 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import GoogleMobileAds
import UserMessagingPlatform

/// The Google Mobile Ads SDK provides the User Messaging Platform (Google's
/// IAB Certified consent management platform) as one solution to capture
/// consent for users in GDPR impacted countries. This is an example and
/// you can choose another consent management platform to capture consent.

@MainActor
public class GoogleMobileAdsConsentManager: NSObject {
    public static let shared = GoogleMobileAdsConsentManager()
    
    public var canRequestAds: Bool {
        return ConsentInformation.shared.canRequestAds
    }
    
    // 此值 返回 true
    // 需要显示一个选项
    // 调用 presentPrivacyOptionsForm() 进行 弹窗展示
    public var isPrivacyOptionsRequired: Bool {
        return ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
    
    public func reset(){
        ConsentInformation.shared.reset()
    }
    
    /// Helper method to call the UMP SDK methods to request consent information and load/present a
    /// consent form if necessary.
    public func gatherConsent(
        testIdentifiers : [String],
        from viewController: UIViewController? = nil,
        consentGatheringComplete: @escaping @MainActor (Error?) -> Void
    ) {
        let parameters = RequestParameters()
        
        if !testIdentifiers.isEmpty{
            // For testing purposes, you can use UMPDebugGeography to simulate a location.
            let debugSettings = DebugSettings()
            debugSettings.testDeviceIdentifiers = testIdentifiers
            // 测试欧盟地区
            debugSettings.geography = DebugGeography.EEA
            parameters.debugSettings = debugSettings
        }
        
        // Indicate the user is under age of consent.
        parameters.isTaggedForUnderAgeOfConsent = false
        
        // Requesting an update to consent information should be called on every app launch.
        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) {
            requestConsentError in
            guard requestConsentError == nil else {
                Task { @MainActor in
                    consentGatheringComplete(requestConsentError)
                }
                return
            }
            
            Task { @MainActor in
                do {
                    try await ConsentForm.loadAndPresentIfRequired(from: viewController)
                    // Consent has been gathered.
                    consentGatheringComplete(nil)
                } catch {
                    consentGatheringComplete(error)
                }
            }
        }
    }
    
    /// Helper method to call the UMP SDK method to present the privacy options form.
    @MainActor public func presentPrivacyOptionsForm(from viewController: UIViewController? = nil)
    async throws
    {
        try await ConsentForm.presentPrivacyOptionsForm(from: viewController)
    }
}
