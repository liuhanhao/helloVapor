//
//  ADSChatBaseModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/14.
//

import Foundation
import ObjectMapper

class ADSChatBaseModel: NSObject, Mappable {
    
    override init() {
        super.init()
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
