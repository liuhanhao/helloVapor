//
//  ADSChatUserModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import ObjectMapper

@objcMembers class ADSChatUserModel: ADSChatBaseModel {

    ///默认登录用户
    let shareInfo = ADSChatUserModel.init(uid: "00001",
                                          name: "无敌是多么的寂寞",
                                          avatar: "http://sqb.wowozhe.com/images/home/wx_appicon.png")
    ///用户id
    var uid: String?
    ///用户昵称
    var name: String?
    ///用户头像 http://sqb.wowozhe.com/images/home/wx_appicon.png
    var avatar: String?
    ///聊天界面是否显示用户昵称
    var showName: Bool = false
    
    init(uid: String, name: String, avatar: String, showName: Bool = false) {
        super.init()
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.showName = showName
    }
    
    required init?(map: Map) {
        super.init(map: map)
//        // 检查 JSON 里是否有一定要有的 "name" 属性
//        if map.JSON["name"] == nil {
//            return nil
//        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // Mappable
    override func mapping(map: Map) { // 支持点语法
        super.mapping(map: map)
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
