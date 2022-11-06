//
//  ADSRecordAnimation.swift
//  VaporChat
//
//  Created by admin on 2022/9/16.
//

import UIKit

class ADSRecordAnimation: UIImageView {
    
    ///设置声音大小 (0 ~ 1)
    var _volume: CGFloat = 0.0
    var volume: CGFloat {
        set {
            if _volume == newValue {
                return
            }
            _volume = min(max(volume, 0.0), 1.0)
            self.showVoiceAnimation() // 开始动画
        }
        get {
            return _volume
        }
    }
    ///录音时长
    var duration: CGFloat = 0.0
    var begin: Bool = false
    
    var _images: [UIImage] = []
    var _nowTime: CGFloat = 0.0
    
    init() {
        super.init(frame: CGRect.init(x: (ADSInputHelper.sharedHelper.screenW() - 120.0) / 2.0, y: ADSInputHelper.sharedHelper.screenH() / 2.0 - 120.0, width: 120.0, height: 120.0))
        self.animationDuration = 0.2
        self.animationRepeatCount = 0
        
        let imageNames = ["wzm_voice_1","wzm_voice_2","wzm_voice_3","wzm_voice_4","wzm_voice_5","wzm_voice_6"]
        for item in imageNames {
            let image = UIImage.init(named: item)
            _images.append(image!)
        }
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func beginRecord() -> Bool {
        guard self.begin == false else {
            return false
        }
        self.begin = true
        _nowTime = self.nowTimestamp()
        if self.superview == nil {
            let window:UIWindow! = UIApplication.shared.keyWindow
            window.addSubview(self)
            self.showVoiceAnimation()
        }
        return true
    }
    
    func endRecord() -> Bool {
        guard self.begin else {
            return false
        }
        
        self.begin = false
        self.duration = self.nowTimestamp() - _nowTime
        if self.duration > 1000 {
            // 录音完成
            if self.superview != nil {
                self.removeFromSuperview()
            }
            return true
        } else {
            self.showVoiceShort()
            // 录音时间太短
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                if self.begin == false {
                    if self.superview != nil {
                        self.removeFromSuperview()
                    }
                }
            })
            return false
        }
    }
    
    func cancelRecord() -> Bool {
        guard self.begin else {
            return false
        }
        
        self.begin = false
        if self.superview != nil {
            self.removeFromSuperview()
        }
        return true
    }
    
    func nowTimestamp() -> TimeInterval {
        let date = Date.init(timeIntervalSinceNow: 0)
        let time = date.timeIntervalSince1970 * 1000
        return time
    }
    
    func showVoiceCancel() {
        self.stopAnimating()
        self.image = ADSInputHelper.otherImageNamed(name: "voice_cancel")
    }
    
    func showVoiceShort() {
        self.stopAnimating()
        self.image = ADSInputHelper.otherImageNamed(name: "voice_short")
    }
    
    func showVoiceAnimation() {
        if volume >= 0.8 {
            self.animationImages = [_images[4],_images[5]]
        } else if volume >= 0.6 {
            self.animationImages = [_images[3],_images[4]]
        } else if volume >= 0.4 {
            self.animationImages = [_images[2],_images[3]]
        } else if volume >= 0.2 {
            self.animationImages = [_images[1],_images[2]]
        } else {
            self.animationImages = [_images[0],_images[1]]
        }
        self.startAnimating()
    }
    
    override func removeFromSuperview() {
        self.image = nil
        self.stopAnimating()
        self.animationImages = nil
        super.removeFromSuperview()
    }
    
}
