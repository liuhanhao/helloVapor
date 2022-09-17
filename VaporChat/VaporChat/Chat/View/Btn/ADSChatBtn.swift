//
//  ADSChatBtn.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit

enum ADSChatButtonType : Int {
    case ADSChatButtonTypeNormal = 0,   //系统默认类型
         ADSChatButtonTypeRetry        //重发消息按钮
}

class ADSChatBtn: UIButton {

    var type: ADSChatButtonType = .ADSChatButtonTypeNormal
    
    static func chatButtonWithType(type: ADSChatButtonType) -> ADSChatBtn {
        let baseBtn: ADSChatBtn = Self.init(type: ButtonType.custom)
        baseBtn.type = type
        
        return baseBtn
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        if (self.currentImage != nil) {
            if type == .ADSChatButtonTypeRetry {
                return CGRect.init(x: 12.5, y: 12.5, width: 15, height: 15)
            }
        }
        
        return super.imageRect(forContentRect: contentRect)
    }
    
}
