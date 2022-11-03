//
//  ADSInputView.swift
//  VaporChat
//
//  Created by admin on 2022/9/16.
//

import UIKit
import Foundation

@objc protocol WZMInputViewDelegate {
    ///文本变化
    @objc optional func inputView(_: ADSInputView, didChangeText text: String)
    ///发送文本消息
    @objc optional func inputView(_: ADSInputView, sendMessage message: String)
    @objc optional func inputView(_: ADSInputView, didSelectMoreType inputMoreType: Int)
    @objc optional func inputView(_: ADSInputView, didChangeRecordType recordType: Int)
    @objc optional func inputView(_: ADSInputView, willChangeFrameWithDuration duration: CGFloat)
}

class ADSInputView: WZMBaseInputView, ADSToolViewDelegate, ADSEmojisKeyboardDelegate, ADSMoreKeyboardDelegate {
    
    weak var delegate: WZMInputViewDelegate?
    
    lazy var inputToolView: ADSToolView = {
        let _inputToolView = ADSToolView.init(frame: CGRect.init(x: 0, y: 0, width: self.bounds.size.width, height: 50+ADSInputHelper.sharedHelper.iPhoneXBottomH()))
        _inputToolView.delegate = self
        _inputToolView.backgroundColor = UIColor(ts_red: 250, green: 250, blue: 250)
        
        return _inputToolView
    }()
    lazy var moreKeyboard: ADSMoreKeyboard = {
        let _moreKeyboard = ADSMoreKeyboard.init(frame: CGRect.init(x: 0, y: self.toolView!.bounds.size.height-ADSInputHelper.sharedHelper.iPhoneXBottomH(), width: self.bounds.size.width, height: 200+ADSInputHelper.sharedHelper.iPhoneXBottomH()))
        _moreKeyboard.delegate = self
        _moreKeyboard.isHidden = true
        _moreKeyboard.backgroundColor = UIColor.white
        
        return _moreKeyboard
    }()
    lazy var emojisKeyboard: ADSEmojisKeyboard = {
        let _emojisKeyboard = ADSEmojisKeyboard(frame: CGRect.init(x: 0, y: self.toolView!.bounds.size.height-ADSInputHelper.sharedHelper.iPhoneXBottomH(), width: self.bounds.size.width, height: 200+ADSInputHelper.sharedHelper.iPhoneXBottomH()))
        _emojisKeyboard.delegate = self
        _emojisKeyboard.isHidden = true
        _emojisKeyboard.backgroundColor = UIColor.white
        
        return _emojisKeyboard
    }()
    
    var _toolView: UIView?
    var _keyboards: [UIView]?
    
    //注意事项：
    //inputView在使用的时候要添加在self.view上(必须要保证inputView的父视图的高度和屏幕的高度一样)
    //因为计算键盘弹起的高度是基于屏幕的高度计算的，如果inputView的父视图和屏幕大小不一致，还要去计算高度的差值
    ///实现以下三个数据源方法, 供父类调用
    override func toolViewOfInputView() -> UIView {
        if _toolView == nil {
            _toolView = self.inputToolView
        }
        return _toolView!
    }
    
    override func keyboardsOfInputView() -> [UIView] {
        if _keyboards == nil {
            _keyboards = [self.emojisKeyboard,self.moreKeyboard]
        }
        return _keyboards!
    }
    
    override func startYOfInputView() -> CGFloat {
        return UIScreen.main.bounds.size.height - self.inputToolView.bounds.size.height
    }
    
    //toolView 代理事件
    func toolView(toolView: ADSToolView, didSelectAtIndex index: Int) {
        
    }
    
    func toolView(toolView: ADSToolView, showKeyboardType type: ADSKeyboardType) {
        if type == .ADSKeyboardTypeSystem {
            self.showSystemKeyboard()
        } else if type == .ADSKeyboardTypeEmoticon {
            self.showKeyboardAtIndex(index: 0, duration: 0.3)
        } else if type == .ADSKeyboardTypeMore {
            self.showKeyboardAtIndex(index: 1, duration: 0.3)
        } else {
            self .dismissKeyboard()
        }
    }
    
    func toolView(toolView: ADSToolView, didChangeRecordType type: ADSRecordType) {
        self.delegate?.inputView?(self, didChangeRecordType: type.rawValue)
    }
    
    //表情键盘
    func emojisKeyboardDidSelectSend(emojisKeyboard: ADSEmojisKeyboard) {
        //发送按钮
        self.sendText()
    }
    
    func emojisKeyboardDidSelectDelete(emojisKeyboard: ADSEmojisKeyboard) {
        //删除键
        self.deleteSelectedText()
    }
    
    func emojisKeyboard(emojisKeyboard: ADSEmojisKeyboard, didSelectText text: String) {
        //选择表情
        self.replaceSelectedTextWithText(text: text)
    }
    
    //more键盘
    func moreKeyboard(moreKeyboard: ADSMoreKeyboard, didSelectType type: ADSInputMoreType) {
        //点击按钮类型
        self.delegate?.inputView?(self, didSelectMoreType: type.rawValue)
    }
    
    /// 父类回调事件
    //点击return键
    override func shouldReturn() -> Bool {
        self.sendText()
        return false
    }
    ///开始编辑
    override func didBeginEditing() {
        self.resetToolViewStatus()
    }
    ///输入框值改变
    override func valueDidChange() {
        self.delegate?.inputView?(self, didChangeText: self.text ?? "")
    }
    
    ///还原视图
    override func willResetConfig() {
        self.resetToolViewStatus()
    }
    
    ///视图frameb改变
    override func willChangeFrameWithDuration(duration: CGFloat) {
        self.delegate?.inputView?(self, willChangeFrameWithDuration: duration)
    }
    
    // private method
    func resetToolViewStatus() {
        self.inputToolView.resetStatus()
    }
    ///点击发送按钮, 包括系统键盘和自定义表情键盘的发送按钮
    func sendText() {
        if let text = self.text {
            if text.ts_length > 0 {
                self.delegate?.inputView?(self, sendMessage: text)
            }
        }
        self.text = ""
    }
}
