//
//  ADSToolView.swift
//  VaporChat
//
//  Created by admin on 2022/9/16.
//

import UIKit

protocol ADSToolViewDelegate: NSObjectProtocol {
    func toolView(toolView: ADSToolView, didSelectAtIndex index: Int)
    func toolView(toolView: ADSToolView, showKeyboardType type: ADSKeyboardType)
    func toolView(toolView: ADSToolView, didChangeRecordType type: ADSRecordType)
}

class ADSToolView: UIView {
    
    weak open var delegate: ADSToolViewDelegate?
    
    var _toolBtns: [UIButton] = []
    var _recordBtn: UIButton
    
    lazy var recordAnimation: ADSRecordAnimation = {
        return ADSRecordAnimation.init()
    }()
    
    override init(frame: CGRect) {
        _recordBtn = UIButton.init(type: UIButton.ButtonType.custom)
        super.init(frame: frame)
        
        let toolW = self.bounds.size.width
        let lineView = UIView.init(frame: CGRect.init(x: 0, y: 0, width: toolW, height: 0.5))
        lineView.backgroundColor = UIColor.init(ts_red: 200, green: 200, blue: 200)
        self.addSubview(lineView)
        
        let textView: UITextView = UITextView.init(frame: CGRect.init(x: 40, y: 7, width: toolW - 120, height: 35))
        textView.font = UIFont.systemFont(ofSize: 13)
        textView.textColor = UIColor.darkText
        textView.returnKeyType = UIReturnKeyType.send
        textView.layer.masksToBounds = true
        textView.layer.cornerRadius = 2
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.init(ts_red: 200, green: 200, blue: 200).cgColor
        self.addSubview(textView)
        
        _recordBtn.frame = textView.frame
        _recordBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        _recordBtn.backgroundColor = UIColor.white
        _recordBtn.layer.masksToBounds = true
        _recordBtn.layer.cornerRadius = 2
        _recordBtn.layer.borderWidth = 0.5
        _recordBtn.layer.borderColor = UIColor.init(ts_red: 200, green: 200, blue: 200).cgColor
        _recordBtn.setTitle("按住 说话", for: UIControl.State.normal)
        _recordBtn.setTitleColor(UIColor.darkGray, for: UIControl.State.normal)
        _recordBtn.addTarget(self, action: #selector(self.touchDown(btn:)), for: UIControl.Event.touchDown)
        _recordBtn.addTarget(self, action: #selector(self.touchCancel(btn:)), for: UIControl.Event.touchCancel)
        _recordBtn.addTarget(self, action: #selector(self.touchCancel(btn:)), for: UIControl.Event.touchUpOutside)
        _recordBtn.addTarget(self, action: #selector(self.touchFinish(btn:)), for: UIControl.Event.touchUpInside)
        _recordBtn.addTarget(self, action: #selector(self.touchDragInside(btn:)), for: UIControl.Event.touchDragInside)
        _recordBtn.addTarget(self, action: #selector(self.touchDragOutside(btn:)), for: UIControl.Event.touchDragOutside)
        _recordBtn.isHidden = true
        self.addSubview(_recordBtn)
        
        var array: [UIButton] = []
        let images = ["wzm_chat_voice","wzm_chat_emotion","wzm_chat_more"]
        let keyboardImg = ADSInputHelper.otherImageNamed(name: "wzm_chat_board")
        for i in 0..<3 {
            let btn = ADSInputBtn.chatButtonWithType(type: ADSInputBtnType.ADSInputBtnTypeTool)
            if i == 0 {
                btn.frame = CGRect.init(x: 0, y: 5, width: 40, height: 40)
            } else if i == 1 {
                btn.frame = CGRect.init(x: toolW - 80, y: 5, width: 40, height: 40)
            } else {
                btn.frame = CGRect.init(x: toolW - 40, y: 5, width: 40, height: 40)
            }
            btn.tag = i
            btn.setImage(ADSInputHelper.otherImageNamed(name: images[i]), for: UIControl.State.normal)
            btn.setImage(keyboardImg, for: UIControl.State.selected)
            btn.addTarget(self, action: #selector(self.btnClick(btn:)), for: UIControl.Event.touchUpInside)
            self.addSubview(btn)
            array.append(btn)
        }
        
        _toolBtns = array
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func resetStatus() {
        _recordBtn.isHidden = true
        for button in _toolBtns {
            button.isSelected = false
        }
    }
    
    @objc func btnClick(btn: UIButton) {
        var type: ADSKeyboardType
        if btn.tag == 0 {
            // 语音按钮
            if btn.isSelected {
                _recordBtn.isHidden = true
                type = ADSKeyboardType.ADSKeyboardTypeSystem
            } else {
                _recordBtn.isHidden = false
                type = ADSKeyboardType.ADSKeyboardTypeIdle
            }
        } else if btn.tag == 1 {
            // 表情按钮
            _recordBtn.isHidden = true
            if btn.isSelected {
                type = ADSKeyboardType.ADSKeyboardTypeSystem
            } else {
                type = ADSKeyboardType.ADSKeyboardTypeEmoticon
            }
        } else {
            // 更多按钮
            _recordBtn.isHidden = true
            if btn.isSelected {
                type = ADSKeyboardType.ADSKeyboardTypeSystem
            } else {
                type = ADSKeyboardType.ADSKeyboardTypeMore
            }
        }
        
        //设置btn状态
        for button in _toolBtns {
            if (button.tag == btn.tag) {
                button.isSelected = !button.isSelected
            }
            else {
                button.isSelected = false
            }
        }
        //调用代理
        self.delegate?.toolView(toolView: self, didSelectAtIndex: btn.tag)
        self.delegate?.toolView(toolView: self, showKeyboardType: type)
    }
    
    @objc func touchDown(btn: UIButton) {
        _recordBtn.setTitle("松开 结束", for: UIControl.State.normal)
        _recordBtn.setTitleColor(UIColor.darkText, for: UIControl.State.normal)
        self.didChangeRecordType(touchEvent: UIControl.Event.touchDown)
        //开始录音
        let _ = self.recordAnimation.beginRecord()
    }
    
    @objc func touchCancel(btn: UIButton) {
        _recordBtn.setTitle("按住 说话", for: UIControl.State.normal)
        _recordBtn.setTitleColor(UIColor.darkGray, for: UIControl.State.normal)
        self.didChangeRecordType(touchEvent: UIControl.Event.touchCancel)
        // 取消录音
        let _ = self.recordAnimation.cancelRecord()
    }
    
    @objc func touchFinish(btn: UIButton) {
        _recordBtn.setTitle("按住 说话", for: UIControl.State.normal)
        _recordBtn.setTitleColor(UIColor.darkGray, for: UIControl.State.normal)
        if self.recordAnimation.endRecord() { //结束录音
            self.didChangeRecordType(touchEvent: UIControl.Event.touchUpInside)
        } else { //录音时长小于1秒, 取消录音
            self.didChangeRecordType(touchEvent: UIControl.Event.touchCancel)
        }
    }
    
    @objc func touchDragOutside(btn: UIButton) {
        _recordBtn.setTitle("松开 结束", for: UIControl.State.normal)
        _recordBtn.setTitleColor(UIColor.darkText, for: UIControl.State.normal)
        self.recordAnimation.showVoiceCancel()
    }
    
    @objc func touchDragInside(btn: UIButton) {
        _recordBtn.setTitle("松开 结束", for: UIControl.State.normal)
        _recordBtn.setTitleColor(UIColor.darkText, for: UIControl.State.normal)
        self.recordAnimation.showVoiceAnimation()
    }
    
    func didChangeRecordType(touchEvent: UIControl.Event) {
        var type: ADSRecordType = ADSRecordType.ADSRecordTypeCancel
        if touchEvent == UIControl.Event.touchDown {
            type = ADSRecordType.ADSRecordTypeBegin
        } else if touchEvent == UIControl.Event.touchUpInside {
            type = ADSRecordType.ADSRecordTypeFinish
        }
        
        self.delegate?.toolView(toolView: self, didChangeRecordType: type)
    }
    
}
