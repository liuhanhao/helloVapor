//
//  Extension+ADSChat.swift
//  VaporChat
//
//  Created by admin on 2022/9/14.
//

import UIKit

extension DateFormatter {
    
    static var formatterCache: [String: DateFormatter] = [:]
    
    static func chat_dateFormatter(f: String) -> DateFormatter {
        guard let formatter:DateFormatter = formatterCache[f] else {
            let formatter = DateFormatter.init()
            formatter.dateFormat = f
            
            formatterCache[f] = formatter
            return formatter
        }
        
        return formatter
    }
    
    static func chat_defaultDateFormatter() -> DateFormatter {
        let f:String = "yyyy-MM-dd HH:mm:ss"
        return self.chat_dateFormatter(f: f)
    }
    
    static func chat_detailDateFormatter() -> DateFormatter {
        let f:String = "yyyy-MM-dd HH:mm:ss.SSS EEEE"
        return self.chat_dateFormatter(f: f)
    }
}

extension UIView {
    
    var chat_minX: CGFloat {
        set {
            var rect = self.frame
            rect.origin.x = newValue
            self.frame = rect
        }
        get {
            return self.frame.minX
        }
    }
    
    var chat_maxX: CGFloat {
        set {
            var rect = self.frame
            rect.origin.x = newValue - rect.width
            self.frame = rect
        }
        get {
            return self.frame.maxX
        }
    }
    
    var chat_minY: CGFloat {
        set {
            var rect = self.frame
            rect.origin.y = newValue
            self.frame = rect
        }
        get {
            return self.frame.minY
        }
    }
    
    var chat_maxY: CGFloat {
        set {
            var rect = self.frame
            rect.origin.y = newValue - rect.height
            self.frame = rect
        }
        get {
            return self.frame.maxY
        }
    }
    
    var chat_centerX: CGFloat {
        set {
            self.center = CGPoint.init(x: newValue, y: self.frame.midY)
        }
        get {
            return self.frame.midX
        }
    }
    
    var chat_centerY: CGFloat {
        set {
            self.center = CGPoint.init(x: self.frame.midX, y: newValue)
        }
        get {
            return self.frame.midY
        }
    }
    
    var chat_postion: CGPoint {
        set {
            var rect = self.frame
            rect.origin.x = newValue.x
            rect.origin.y = newValue.y
            self.frame = rect
        }
        get {
            CGPoint.init(x: self.frame.origin.x, y: self.frame.origin.y)
        }
    }
    
    var chat_width: CGFloat {
        set {
            var rect = self.frame
            rect.size.width = newValue
            self.frame = rect
        }
        get {
            self.frame.width
        }
    }
    
    var chat_height: CGFloat {
        set {
            var rect = self.frame
            rect.size.height = newValue
            self.frame = rect
        }
        get {
            self.frame.height
        }
    }
    
    var chat_size: CGSize {
        set {
            var rect = self.frame
            rect.size.width = newValue.width
            rect.size.height = newValue.height
            self.frame = rect
        }
        get {
            CGSize.init(width: self.chat_width, height: self.chat_height)
        }
    }
    
    var chat_cornerRadius: CGFloat {
        set {
            self.layer.masksToBounds = true
            self.layer.cornerRadius = newValue
        }
        get {
            self.layer.cornerRadius
        }
    }
    
    var chat_borderWidth: CGFloat {
        set {
            self.layer.borderWidth = newValue
        }
        get {
            self.layer.borderWidth
        }
    }
    
    var chat_borderColor: UIColor? {
        set {
            self.layer.borderColor = newValue?.cgColor
        }
        get {
            guard let borderColor = self.layer.borderColor else {
                return nil
            }
            return UIColor.init(cgColor: borderColor)
        }
    }
    
    func chat_viewController() -> UIViewController? {
        
        var next: UIResponder? = self.next
        repeat {
            if next != nil {
                if next!.isKind(of: UIViewController.self) {
                    return next as? UIViewController
                }
                
                next = next?.next
            }
        } while next != nil
        
        return nil
    }
    
    
}
