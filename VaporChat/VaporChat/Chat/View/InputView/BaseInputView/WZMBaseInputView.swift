//
//  WZMBaseInputView.swift
//  VaporChat
//
//  Created by admin on 2022/10/17.
//

import UIKit

class WZMBaseInputView: UIView,UITextViewDelegate,UITextFieldDelegate {

    ///初始y值
    var startY: CGFloat = 0.0
    ///toolView的高度
    var toolViewH: CGFloat = 0.0
    ///当前键盘的高度
    var keyboardH: CGFloat = 0.0
    ///保存子类实现的输入框, 用来弹出系统键盘
    var inputView1: UITextView?
    var inputView2: UITextField?

    ///顶部toolView, 输入框就在这个view上
    var toolView: UIView?
    ///自定义键盘, 须子类使用方法传入
    var keyboards: [UIView] = []
    ///当前键盘类型
    var type: ADSKeyboardType
    ///当前键盘索引, -1为z系统键盘
    var keyboardIndex: Int
    ///是否处于编辑状态, 自定义键盘模式也认定为编辑状态
    var editing: Bool
    //获取/设置输入框字符串
    var text: String? {
        get {
            if self.inputView1 != nil {
                return self.inputView1!.text
            }
            if self.inputView2 != nil {
                return self.inputView2!.text
            }
            return nil
        }
        set {
            if self.inputView1 != nil {
                self.inputView1!.text = newValue
            }
            if self.inputView2 != nil {
                self.inputView2!.text = newValue
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.prepareInit()
        self.createViews()
    }
    convenience init() {
        self.init(frame: UIScreen.main.bounds)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func prepareInit() {
        self.startY = -1
        self.editing = false
        self.keyboardIndex = -1
        self.type = ADSKeyboardType.ADSKeyboardTypeIdle
        NotificationCenter.default.addObserver(self, selector: #selector(WZMBaseInputView.keyboardValueChange(notification:)), name: WZMBaseInputView.keyboardWillChangeFrameNotification, object: nil)
    }
    
    func createViews() {
        self.backgroundColor = UIColor.white
        self.toolView = self.toolViewOfInputView()
        self.toolViewH = self.toolView!.bounds.size.height
        for i in 0..<self.toolView!.subviews.count {
            let view = self.toolView!.subviews[i]
            if view.isKind(of: UITextView.self) {
                self.inputView1 = view as? UITextView
                self.inputView1?.delegate = self
                break
            }
            if view.isKind(of: UITextField.self) {
                self.inputView2 = view as? UITextField
                self.inputView2?.delegate = self
                NotificationCenter.default.addObserver(self, selector: #selector(WZMBaseInputView.textFieldDidChange(notification:)), name: UITextField.textDidChangeNotification, object: nil)
                break
            }
        }
        self.addSubview(self.toolView!)
        self.keyboards = self.keyboardsOfInputView()
        for i in 0..<self.toolView!.subviews.count {
            let keyboard = self.toolView!.subviews[i]
            keyboard.isHidden = true
            self.addSubview(keyboard)
        }
        self.startY = self.startYOfInputView()
    }
    
    //使用时只需要调用这两个方法即可
    func chatBecomeFirstResponder() {
        self.showSystemKeyboard()
    }
    func chatResignFirstResponder() {
        self.willResetConfig()
        self.dismissKeyboard()
    }
    
    // 监听键盘变化
    @objc func keyboardValueChange(notification: Notification) {
        let dic: Dictionary = notification.userInfo!
    
        var number: NSNumber = dic["UIKeyboardAnimationDurationUserInfoKey"] as! NSNumber
        let duration: CGFloat = CGFloat(number.floatValue)
        
        number = dic["UIKeyboardFrameBeginUserInfoKey"] as! NSNumber
        let beginFrame: CGRect = number.cgRectValue
        
        number = dic["UIKeyboardFrameEndUserInfoKey"] as! NSNumber
        let endFrame: CGRect = number.cgRectValue

        if beginFrame.origin.y < endFrame.origin.y {
            if self.keyboardIndex == -1 {
                //系统键盘收回
                self.keyboardH = 0
            }
        }
        if (beginFrame.origin.y < endFrame.origin.y) {
            if (self.keyboardIndex == -1) {
                //系统键盘收回
                self.minYWillChange(minY: self.startY, duration: duration, dismissKeyboard: true)
            }
            else {
                //自定义键盘弹出
                self.wzm_showKeyboardAtIndex(index: self.keyboardIndex, duration: duration)
            }
        }
        else {
            //系统键盘弹出
            self.keyboardH = endFrame.size.height
            self.keyboardIndex = -1
            self.type = ADSKeyboardType.ADSKeyboardTypeSystem
            let minY = endFrame.origin.y-self.toolView!.bounds.size.height
            self.minYWillChange(minY: minY, duration: duration, dismissKeyboard: false)
            DispatchQueue.main.asyncAfter(deadline: .now()+0.3, execute:
            {
                //自定义键盘隐藏
                for i in 0..<self.keyboards.count {
                    let view = self.keyboards[i]
                    view.isHidden = true
                }
            })

        }
    }
    
    func minYWillChange(minY: CGFloat, duration: CGFloat, dismissKeyboard: Bool) {
        if dismissKeyboard {
            self.keyboardIndex = -1
            self.type = ADSKeyboardType.ADSKeyboardTypeIdle
        }
        var _minY = minY
        if minY < self.startY {
            _minY = minY + ADSInputHelper.sharedHelper.iPhoneXBottomH()
            self.keyboardH = ADSInputHelper.sharedHelper.iPhoneXBottomH() - self.keyboardH
        }
        
        var endFrame = self.frame
        endFrame.origin.y = _minY
        UIView.animate(withDuration: duration) {
            self.frame = endFrame
        }
        self.willChangeFrameWithDuration(duration: duration)
    }
    
    ///子类设置toolView和keyboards
    func toolViewOfInputView() -> UIView {
        return UIView()
    }
    func keyboardsOfInputView() -> [UIView] {
        return []
    }

    ///视图的初始y值
    func startYOfInputView() -> CGFloat {
        if self.startY == -1 {
            self.startY = UIScreen.main.bounds.size.height - self.toolViewH
        }
        return self.startY
    }

    ///开始编辑
    func didBeginEditing() {
        
    }

    ///结束编辑
    func didEndEditing() {
        
    }

    ///输入框值改变
    func valueDidChange() {
        
    }
    ///是否允许开始编辑
    func shouldBeginEditing() -> Bool {
        return true
    }
    
    ///是否允许结束编辑
    func shouldEndEditing() -> Bool {
        return true
    }

    ///是否允许点击return键
    func shouldReturn() -> Bool {
        return true
    }

    ///是否允许编辑
    func shouldChangeTextInRange(range: NSRange, text: String) -> Bool {
        return true
    }

    ///还原视图
    func willResetConfig() {
        
    }

    ///视图frameb改变
    func willChangeFrameWithDuration(duration: CGFloat) {
        
    }

    /// 键盘事件处理
    func showSystemKeyboard() {
        if self.type != ADSKeyboardType.ADSKeyboardTypeSystem {
            self.type = ADSKeyboardType.ADSKeyboardTypeSystem
            if self.inputView1 != nil {
                self.inputView1?.becomeFirstResponder()
            } else if self.inputView2 != nil {
                self.inputView2?.becomeFirstResponder()
            }
        }
    }

    //判断是否直接弹出自定义键盘
    func showKeyboardAtIndex(index: Int, duration: CGFloat) {
        if index < 0 || index >= self.keyboards.count || self.keyboardIndex == index {
            return
        }
        if self.type == ADSKeyboardType.ADSKeyboardTypeSystem {
            //由系统键盘弹出自定义键盘
            //系统键盘收回, 在键盘监听事件中弹出自定义键盘
            self.keyboardIndex = index
            self.endEditing(true)
        } else {
            self.keyboardIndex = index
            //直接弹出自定义键盘
            self.wzm_showKeyboardAtIndex(index: index, duration: duration)
        }
    }

    func dismissKeyboard() {
        if self.type == ADSKeyboardType.ADSKeyboardTypeIdle {
            return
        }
        if self.type == ADSKeyboardType.ADSKeyboardTypeSystem {
            self.endEditing(true)
        } else {
            self.keyboardH = 0
            self.minYWillChange(minY: self.startY, duration: 0.25, dismissKeyboard: true)
        }
        for view in self.keyboards {
            view.isHidden = true
        }
    }

    //直接弹出自定义键盘
    func wzm_showKeyboardAtIndex(index: Int, duration: CGFloat) {
        //直接弹出自定义键盘
        self.type = ADSKeyboardType.ADSKeyboardTypeOther
        var k: UIView?
        for i in 0..<self.keyboards.count {
            let other: UIView = self.keyboards[i]
            if i == index {
                other.isHidden = false
                k = other
            } else {
                other.isHidden = true
            }
        }
        if k != nil {
            self.keyboardH = k!.bounds.size.height
            var minY: CGFloat
            if self.startY >= UIScreen.main.bounds.size.height {
                //如果放在视图最下面,还需要再减去self.toolViewH
                minY = self.startY-self.keyboardH-self.toolViewH
            } else {
                minY = self.startY-self.keyboardH
            }
            self.minYWillChange(minY: minY, duration: duration, dismissKeyboard: false)
        }
    }

    ///输入框字符串处理
    func replaceSelectedTextWithText(text: String) {
        if self.inputView1 != nil {
            self.inputView1!.replace(self.inputView1!.selectedTextRange!, withText: text)
        }
        if self.inputView2 != nil {
            self.inputView2!.replace(self.inputView2!.selectedTextRange!, withText: text)
        }
    }

    func deleteSelectedText() {
        if self.inputView1 != nil {
            if self.inputView1!.text.count > 0 {
                let range: NSRange = self.inputView1!.selectedRange
                let location: Int = range.location
                let length: Int = range.length
                if location == 0 && length == 0 {
                    return
                }
                if length > 0 {
                    self.inputView1!.deleteBackward()
                } else {
                    let subString: String = self.inputView1!.text.substring(to: location)
                    let emoticon: String? = ADSEmoticonManager.manager().willDeleteEmoticon(aString: subString)
                    if emoticon != nil && ADSEmoticonManager.shared.chs.contains(emoticon!) {
                        let newLocation = location - emoticon!.count
                        
                        let toBeStr = self.inputView1!.text
                        let rag = toBeStr?.toRange(NSMakeRange(newLocation, emoticon!.count))
                        self.inputView1!.text = toBeStr?.replacingCharacters(in: rag!, with: "")
                        self.inputView1!.selectedRange = NSMakeRange(newLocation, 0)
                        self.valueDidChange()
                    } else {
                        self.inputView1?.deleteBackward()
                    }
                }
            }
        }
        if let inputView2 = self.inputView2  {
            if inputView2.text != nil {
                if inputView2.text!.count > 0 {
                    let textRange: UITextRange? = inputView2.selectedTextRange
                    if let range = textRange {
                        let start: UITextPosition = range.start
                        let end: UITextPosition = range.end
                        let beginning: UITextPosition = inputView2.beginningOfDocument
                        let location: Int = inputView2.offset(from: beginning, to: end)
                        let length: Int = inputView2.offset(from: start, to: end)
                        if location == 0 && length == 0 {
                            return
                        }
                        if length > 0 {
                            inputView2.deleteBackward()
                        } else {
                            let subString: String = inputView2.text!.substring(to: location)
                            let emoticon: String = ADSEmoticonManager.shared.willDeleteEmoticon(aString: subString)!
                            if ADSEmoticonManager.shared.chs.contains(emoticon) {
                                let newLocation = location - emoticon.count
                                let toBeStr = inputView2.text
                                let rag = toBeStr?.toRange(NSMakeRange(newLocation, emoticon.count))
                                inputView2.text = toBeStr?.replacingCharacters(in: rag!, with: "")
                                
                                let beginning: UITextPosition = inputView2.beginningOfDocument
                                let start: UITextPosition = inputView2.position(from: beginning, offset: newLocation)!
                                let end: UITextPosition = inputView2.position(from: start, offset: length)!
                                let textRange: UITextRange = inputView2.textRange(from: start, to: end)!
                                inputView2.selectedTextRange = textRange
                                
                                self.valueDidChange()
                            } else {
                                inputView2.deleteBackward()
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        if let _ = newSuperview {
            var frame = self.frame
            frame.origin.y = self.startY
            self.frame = frame
        }
        super.willMove(toSuperview: newSuperview)
    }

    /// UITextFieldDelegate
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.editing = true
        self.didBeginEditing()
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.editing = false
        self.didEndEditing()
    }
    
    @objc private func textFieldDidChange(notification: Notification) {
        let textField: AnyObject? = notification.object as? AnyObject
        if textField != nil {
            if textField!.isKind(of: UITextField.self) {
                self.valueDidChange()
            }
        }
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return self.shouldBeginEditing()
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return self.shouldEndEditing()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return self.shouldReturn()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string == "" {
            let language = textField.textInputMode?.primaryLanguage
            if language == "zh-Hans" {
                let selectedRange: UITextRange? = textField.markedTextRange
                if selectedRange != nil {
                    return true
                }
            }
            self.deleteSelectedText()
            return false
        }
        return self.shouldChangeTextInRange(range: range, text: string)
    }

    /// UITextViewDelegate
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.editing = true
        self.didBeginEditing()
    }
    func textViewDidEndEditing(_ textView: UITextView) {
        self.editing = false
        self.didEndEditing()
    }
    func textViewDidChange(_ textView: UITextView) {
        self.valueDidChange()
    }
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return self.shouldEndEditing()
    }
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return self.shouldBeginEditing()
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "" {
            let language = textView.textInputMode?.primaryLanguage
            if language == "zh-Hans" {
                let selectedRange: UITextRange? = textView.markedTextRange
                if selectedRange != nil {
                    return true
                }
            }
            self.deleteSelectedText()
            return false
        }
        if text == "\n" || text == "\r" {
            return self.shouldReturn()
        }
        return self.shouldChangeTextInRange(range: range, text: text)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    
}
