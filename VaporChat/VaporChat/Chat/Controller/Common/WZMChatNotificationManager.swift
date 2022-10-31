//
//  WZMChatNotificationManager.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class WZMChatNotificationManager: NSObject {

    ///发送刷新session的通知
    class func postSessionNotification() {
        NotificationCenter.default.post(name: NSNotification.Name("ll.chat.session"), object: nil)
    }
    ///监听刷新session的通知
    class func observerSessionNotification(instant: Any, sel aSelector: Selector) {
        NotificationCenter.default.addObserver(instant, selector: aSelector, name: NSNotification.Name("ll.chat.session"), object: nil)
    }
    ///移除通知
    class func removeObserver(instant: Any) {
        NotificationCenter.default.removeObserver(instant)
    }
}
