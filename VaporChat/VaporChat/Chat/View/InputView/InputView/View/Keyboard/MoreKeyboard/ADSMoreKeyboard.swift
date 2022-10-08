//
//  ADSMoreKeyboard.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/19.
//

import UIKit

protocol ADSMoreKeyboardDelegate : NSObjectProtocol {
    func moreKeyboard(moreKeyboard: ADSMoreKeyboard, didSelectType type: ADSInputMoreType);
}

class ADSMoreKeyboard: UIView {

    weak open var delegate: ADSMoreKeyboardDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let count = 4
        let itemW = 60.0
        let itemH = 80.0
        let left = 20.0
        let spacing = (frame.size.width - itemW * CGFloat(count) - left * 2) / 3
        let images = ["wzm_chat_pic","wzm_chat_video","wzm_chat_locaion","wzm_chat_transfer"]
        let titles = ["图片","视频","待定","待定"]
        
        for (i,item) in images.enumerated() {
            let btn = ADSInputBtn.chatButtonWithType(type: ADSInputBtnType.ADSInputBtnTypeMore)
            btn.frame = CGRect.init(x: left + CGFloat(i % count) * (itemW + spacing), y: CGFloat(i / count) * itemH, width: itemW, height: itemH)
            btn.tag = i
            btn.setTitle(titles[i], for: UIControl.State.normal)
            btn.setImage(ADSInputHelper.otherImageNamed(name: item), for: UIControl.State.normal)
            btn.setTitleColor(UIColor.gray, for: UIControl.State.normal)
            btn.addTarget(self, action: #selector(self.btnClick(btn:)), for: UIControl.Event.touchUpInside)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func btnClick(btn: UIButton) {
        let type = ADSInputMoreType.init(rawValue: btn.tag)!
        self.delegate?.moreKeyboard(moreKeyboard: self, didSelectType: type)
    }
    
}
