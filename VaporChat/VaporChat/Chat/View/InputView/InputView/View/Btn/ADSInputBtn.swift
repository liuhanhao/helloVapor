//
//  ADSInputBtn.swift
//  VaporChat
//
//  Created by admin on 2022/9/16.
//

import UIKit

class ADSInputBtn: UIButton {

    var type: ADSInputBtnType = .ADSInputBtnTypeNormal
    
    static func chatButtonWithType(type: ADSInputBtnType) -> ADSInputBtn {
        let baseBtn = Self.init(type: ButtonType.custom)
        baseBtn.type = type
        
        return baseBtn
    }
    
    //重设image的frame
    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        if (self.currentImage != nil) {
            if type == .ADSInputBtnTypeTool {
                return CGRect.init(x: 5, y: 5, width: 30, height: 30)
            } else if type == .ADSInputBtnTypeMore {
                return CGRect.init(x: 10, y: 15, width: 40, height: 40)
            }
        }
        
        return super.imageRect(forContentRect: contentRect)
    }
    
    //重设title的frame
    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        if type == .ADSInputBtnTypeMore {
            //实际应用中要根据情况，返回所需的frame
            return CGRect.init(x: 0, y: 55, width: 60, height: 25)
        }
        
        return super.titleRect(forContentRect: contentRect)
    }
    
}
