//
//  ATTracker.swift
//  SceneSample
//
//  Created by yyd on 2026/2/26.
//  Copyright © 2026 Apple. All rights reserved.
//

import Foundation
import AppTrackingTransparency

class ATTracker : NSObject{
    static let shared : ATTracker = ATTracker()
    
    
    func request(){
        
        
        AppTrackingTransparency.ATTrackingManager.requestTrackingAuthorization{ st in
            
            if st == .authorized{
                debugPrint("att gardent")
            }else{
                debugPrint("att denied")
            }
            
        }
        
    }
    
    
}
