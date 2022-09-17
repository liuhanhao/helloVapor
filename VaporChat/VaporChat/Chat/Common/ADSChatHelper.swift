//
//  ADSChatHelper.swift
//  VaporChat
//
//  Created by admin on 2022/9/14.
//

import Foundation

class ADSChatHelper: NSObject {
    
    static func nowTimestamp() -> TimeInterval {
        let date = Date.init(timeIntervalSinceNow: 0)
        let time = date.timeIntervalSince1970 * 1000
        return time
    }
    
}
