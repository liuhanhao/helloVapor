//
//  ADSChatBaseModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/14.
//

import Foundation
import ObjectMapper

/*
想要Swift类支持runtime 就必须继承自NSObject  并且在属性或者方法前面加上@objc
*/
@objcMembers class ADSChatBaseModel: NSObject, NSCoding, Mappable {
    
    override init() {
        super.init()
    }
    
    class func chat_unarchiveObjectWithData(data: Data) -> Self {
        if self.conforms(to: NSCoding.self) {
            if class_respondsToSelector(self, #selector(encode(with:))) {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as! Self
            }
        }
    }
    
    ///<model/字典>数据转换
    ///将字典转化为model
    convenience init(WithDic dic: [String : AnyObject]) {
        self.init()
        for (key, value) in dic {
            self.setValue(value, forKey: key)
        }
    }
    
    func encode(with coder: NSCoder) {
        let count = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
        let ivarLists = class_copyIvarList(object_getClass(Self.self), count)
        let countInt = Int(count[0])
        for i in 0..<countInt {
            if let temp = ivarLists?[i], let cname = ivar_getName(temp) {
                let proper = String(cString: cname)
                coder.encode(temp, forKey: proper)
            }
        }
        
        free(ivarLists)
    }
    
    required init?(coder: NSCoder) {
        let count = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
        let ivarLists = class_copyIvarList(object_getClass(Self.self), count)
        let countInt = Int(count[0])
        for i in 0..<countInt {
            if let temp = ivarLists?[i], let cname = ivar_getName(temp) {
                let proper = String(cString: cname)
                let value = coder.decodeObject(forKey: proper)
                if value != nil {
                    self.setValue(value, forKey: proper)
                }
            }
        }
        
        free(ivarLists)
    }
    
    override class func setValue(_ value: Any?, forUndefinedKey key: String) {
        
    }
    
    func _transfromDictionary(model: AnyObject) -> [String : AnyObject] {
        var dic: [String: AnyObject] = [:]
        let count = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
        let propertys = class_copyPropertyList(object_getClass(Self.self), count)
        let countInt = Int(count[0])
        for i in 0..<countInt {
            let aPro: objc_property_t = propertys![i]
            let proName: String = String(cString: property_getName(aPro))
            
            let value = model.value(forKey: proName) as? AnyObject
            if (value != nil) {
                dic[proName] = value
            }
        }
        
        free(propertys)
        return dic
    }
    
    ///将model转化为字典
    func transfromDictionary() -> [String : AnyObject] {
        return self._transfromDictionary(model: self)
    }

    ///获取类的所有属性名称与类型
    class func allPropertyName() -> [String] {
        var arr: NSMutableArray = NSMutableArray.init()
        return self.allPropertyName(arr: arr, _self: self)
    }
    class func allPropertyName(arr: NSMutableArray, _self: AnyClass) -> [String] {
        let superclass: AnyClass? = self._allPropertyName(arr: arr, _self: _self)
        if superclass != nil {
            if superclass! is ADSChatBaseModel.Type  {
                let _ = self.allPropertyName(arr: arr, _self: superclass!)
            }
        }
        return arr as NSArray as! [String]
    }
    
    class func _allPropertyName(arr: NSMutableArray, _self: AnyClass) -> AnyClass? {
        
        let count = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
        let propertys = class_copyPropertyList(object_getClass(_self), count)
        let countInt = Int(count[0])
        for i in 0..<countInt {
            let pro: objc_property_t = propertys![i]
            let name: String = String(cString: property_getName(pro))
            var type: String? = self.attrValue(WithName: "T", InProperty: pro)
            
            //类型转换
            if type == "q" || type == "i" || type == "I" {
                type = "integer"
            } else if type == "f" || type == "d" {
                type = "real"
            } else if type == "B" {
                type = "boolean"
            } else {
                type = "text"
            }
            
            let dict = ["name":name,"type":type]
            arr.add(dict)
        }
        
        free(propertys);
        
        return _self.superclass()
    }
    
    class func attrValue(WithName name: String, InProperty pro: objc_property_t) -> String? {
        let count = UnsafeMutablePointer<UInt32>.allocate(capacity: 0)
        let attrs = property_copyAttributeList(pro, count)
        let countInt = Int(count[0])
        for i in 0..<countInt {
            let attr: objc_property_attribute_t = attrs![i]
            if String(cString: attr.name) == name {
                return String(cString: attr.value)
            }
        }
        free(attrs)
        return nil
    }
    
    required init?(map: Map) {
//        // 检查 JSON 里是否有一定要有的 "name" 属性
//        if map.JSON["name"] == nil {
//            return nil
//        }
    }

    // Mappable
    func mapping(map: Map) { // 支持点语法
//        username    <- map["username"]
//        age         <- map["age"]
//        weight      <- map["weight.head"]
//        array       <- map["arr"]
//        dictionary  <- map["dict"]
//        bestFriend  <- map["best_friend"]
//        friends     <- map["friends"]
//        birthday    <- (map["birthday"], DateTransform())
    }
    
}
