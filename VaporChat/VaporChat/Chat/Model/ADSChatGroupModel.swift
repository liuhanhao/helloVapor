//
//  ADSChatGroupModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import ObjectMapper

class ADSChatGroupModel: ADSChatBaseModel {

    ///用户id
    var uid: String?
    ///用户昵称
    var name: String?
    ///用户头像 http://sqb.wowozhe.com/images/home/wx_appicon.png
    var avatar: String?
    ///聊天界面是否显示用户昵称
    var showName: Bool = false
    // 群成员 成员ID 成员名称 成员头像
    var members: [[String:String]]?
    
    init(uid: String, name: String, avatar: String, showName: Bool = false, members: [[String:String]]?) {
        super.init()
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.showName = showName
        self.members = members
    }
    
    required init?(map: Map) {
        super.init(map: map)
//        // 检查 JSON 里是否有一定要有的 "name" 属性
//        if map.JSON["name"] == nil {
//            return nil
//        }
    }

    // Mappable
    override func mapping(map: Map) { // 支持点语法
        super.mapping(map: map)
        uid         <- map["uid"]
        name        <- map["name"]
        avatar      <- map["avatar"]
        showName    <- map["showName"]
        members     <- map["members"]
    }
    
}
