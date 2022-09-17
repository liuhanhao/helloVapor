//
//  Extension+NSTimer.swift
//  大傻
//
//  Created by Adsmart on 2017/6/13.
//  Copyright © 2017年 Adsmart. All rights reserved.
//

import Foundation
import UIKit

typealias ADSTimerBlock = (Timer) -> ()

extension Timer {
    
    static func scheduledTimerWithTime(timer:Timer?,interval:TimeInterval,target:AnyObject,selector:Selector,userInfo:Dictionary<String, Any>,repeats:Bool) -> Timer {
        
        return self.initWithWeakTimer(timer: timer, interval: interval, target: target, selector: selector, timerBlock: {(timer) in }, userInfo: userInfo, repeats: repeats)
        
    }
    
    static func scheduledTimerWithTime(timer:Timer?,interval:TimeInterval,target:AnyObject,timerBlock:@escaping ADSTimerBlock,userInfo:Dictionary<String, Any>?,repeats:Bool) -> Timer {
        
        return self.initWithWeakTimer(timer: timer, interval: interval, target: target, selector: nil, timerBlock: timerBlock, userInfo: userInfo, repeats: repeats)
        
    }
    
    private
    static func initWithWeakTimer(timer:Timer?,interval:TimeInterval,target:AnyObject,selector:Selector?, timerBlock:@escaping ADSTimerBlock,userInfo:Dictionary<String, Any>?,repeats:Bool) -> Timer {
        
        timer?.invalidate()
        
        let obj = ADSTimeProxy.init()

        if selector == nil {
            
            obj.target = target
            obj.timerBlock = timerBlock
            obj.timer = Timer.scheduledTimer(timeInterval: interval, target: obj, selector: #selector(obj.responseTimer(timer:)), userInfo: userInfo, repeats: repeats)
            
        }
        else {
            
            obj.target = target
            obj.selector = selector
            obj.timer = Timer.scheduledTimer(timeInterval: interval, target: obj, selector: #selector(obj.responseTimer(timer:)), userInfo: userInfo, repeats: repeats)
            
        }
        
        return obj.timer
        
    }
    
}


class ADSTimeProxy {
    
    fileprivate weak var target:AnyObject?
    fileprivate var timer:Timer!
    
    fileprivate var selector:Selector?
    fileprivate var control:UIControl = UIControl.init()
    
    fileprivate var timerBlock:ADSTimerBlock?
    
    @objc fileprivate func responseTimer(timer:Timer) {
        
        if self.target != nil {
            
            if self.timerBlock != nil {
                self.timerBlock!(self.timer)
            }
            else {
                self.control.sendAction(selector!, to: target, for: nil)
            }
            
        }
        else {
         
            self.timer.invalidate()
            self.timer = nil
            
        }
        
    }
    
    deinit {
        print("ADSTimeProxy 被释放了")
    }
    
}

