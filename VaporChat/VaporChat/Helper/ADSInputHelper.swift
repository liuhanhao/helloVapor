//
//  ADSInputHelper.swift
//  翻译
//
//  Created by admin on 2022/9/13.
//

import Foundation
import UIKit
import SwiftUI

class ADSInputHelper: NSObject {
    
    static let sharedHelper:ADSInputHelper = ADSInputHelper.init()
    
    var lxhPath:String {
        get {
            guard let path = Bundle.main.path(forResource: "WZMEmoticon", ofType: "bundle") else { return "" }
            return path + "/emoticon_lxh"
        }
    }
    var otherPath:String {
        get {
            guard let path = Bundle.main.path(forResource: "WZMEmoticon", ofType: "bundle") else { return "" }
            return path + "/emoticon_other"
        }
    }
    var defaultPath:String {
        get {
            guard let path = Bundle.main.path(forResource: "WZMEmoticon", ofType: "bundle") else { return "" }
            return path + "/emoticon_default"
        }
    }
    
    var otherCache:[String:UIImage] = [:]
    var emoticonCache:[String:UIImage] = [:]
    
    
    var _iPad:Int = -1
    var _iPhone:Int = -1
    var _iPhoneX:Int = -1
    var _statusH:CGFloat = 0
    var _navBarH:CGFloat = 0
    var _tabBarH:CGFloat = 0
    
    var _screenH:CGFloat = 0
    var _screenW:CGFloat = 0
    var _screenScale:CGFloat = 0
    var _screenBounds:CGRect = CGRect.null
    
    var _iPhoneXBottomH:CGFloat = 0
    
    private override init() {
        
    }
    
    func reset() {
        _statusH = -1
        _navBarH = -1
        _tabBarH = -1
        _screenW = -1
        _screenH = -1
        _screenScale = -1
        _screenBounds = CGRect.null
        _iPhoneXBottomH = -1
    }
    
    func iPad() -> Bool {
        return UIDevice.ts_isPad()
    }
    
    func iPhone() -> Bool {
        return UIDevice.ts_isPhone()
    }
    
    func iPhoneX() -> Bool {
        if _iPhoneX == -1 {
            if #available(iOS 11.0, *) {
                let appDelegate:AppDelegate = UIApplication.ts_sharedApplication()!.delegate as! AppDelegate
                let iphone = self.iPhone()
                let safeAreaInsets:Bool = appDelegate.window!.safeAreaInsets.bottom > 0.0 ? true : false
                _iPhoneX = (iphone && safeAreaInsets) ? 1 : 0
            }
            else {
                _iPhoneX = 0
            }
        }
        
        return Bool.init(truncating: _iPhoneX as NSNumber)
    }
    
    ///状态栏高
    func statusH() -> CGFloat {
        if _statusH == -1 {
            if #available(iOS 11.0, *) {
                let appDelegate:AppDelegate = UIApplication.ts_sharedApplication()!.delegate as! AppDelegate
                _statusH = appDelegate.window!.safeAreaInsets.top
            }
            else {
                _statusH = 20.0
            }
        }
        
        return _statusH
    }
    
    ///导航高
    func navBarH() -> CGFloat {
        if _navBarH == -1 {
            if #available(iOS 11.0, *) {
                let appDelegate:AppDelegate = UIApplication.ts_sharedApplication()!.delegate as! AppDelegate
                _navBarH = appDelegate.window!.safeAreaInsets.top + 44.0
            }
            else {
                _navBarH = 44.0
            }
        }
        
        return _navBarH
    }
    
    ///taBar高
    func tabBarH() -> CGFloat {
        if _tabBarH == -1 {
            if #available(iOS 11.0, *) {
                let appDelegate:AppDelegate = UIApplication.ts_sharedApplication()!.delegate as! AppDelegate
                _tabBarH = appDelegate.window!.safeAreaInsets.bottom + 49.0
            }
            else {
                _tabBarH = 49.0
            }
        }
        
        return _tabBarH
    }
    
    ///屏幕宽
    func screenW() -> CGFloat {
        if _screenW == -1 {
            _screenW = UIScreen.ts_width
        }
        return _screenW
    }
    
    ///屏幕高
    func screenH() -> CGFloat {
        if _screenH == -1 {
            _screenH = UIScreen.ts_height
        }
        return _screenH
    }
    
    ///屏幕scale
    func screenScale() -> CGFloat {
        if _screenScale == -1 {
            _screenScale = UIScreen.main.scale
        }
        return _screenScale
    }
    
    ///屏幕bounds
    func screenBounds() -> CGRect {
        if _screenBounds == CGRect.null {
            _screenBounds = UIScreen.main.bounds
        }
        return _screenBounds
    }
    
    ///taBar高
    func iPhoneXBottomH() -> CGFloat {
        if _iPhoneXBottomH == -1 {
            if #available(iOS 11.0, *) {
                let appDelegate:AppDelegate = UIApplication.ts_sharedApplication()!.delegate as! AppDelegate
                _iPhoneXBottomH = appDelegate.window!.safeAreaInsets.bottom
            }
            else {
                _iPhoneXBottomH = 0.0
            }
        }
        
        return _iPhoneXBottomH
    }
    
    //图片
    func otherImageNamed(name: String) -> UIImage? {
        if name.ts_length == 0 {
            return nil
        }
        
        var fileName = name
        let url:URL = URL.init(fileURLWithPath: name)
        if url.pathExtension.ts_length == 0 {
            fileName = fileName + ".png"
        }
        
        let helper = ADSInputHelper.sharedHelper
        var image:UIImage? = helper.otherCache[name]
        if image == nil {
            let path = helper.otherPath + "/" + "name"
            image = UIImage.init(contentsOfFile: path)
        }
        
        if image != nil {
            helper.otherCache[name] = image
        }
        
        return image
    }
    
    //图片
    func emoticonImageNamed(name: String) -> UIImage? {
        if name.ts_length == 0 {
            return nil
        }
        
        var fileName = name
        let url:URL = URL.init(fileURLWithPath: name)
        if url.pathExtension.ts_length == 0 {
            fileName = fileName + ".png"
        }
        
        let helper = ADSInputHelper.sharedHelper
        var image:UIImage? = helper.emoticonCache[name]
        if image == nil {
            let path = helper.lxhPath + "/" + "name"
            image = UIImage.init(contentsOfFile: path)
        }
        if image == nil {
            let path = helper.defaultPath + "/" + "name"
            image = UIImage.init(contentsOfFile: path)
        }
        
        if image != nil {
            helper.emoticonCache[name] = image
        }
        
        return image
    }
    
}
