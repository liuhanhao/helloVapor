//
//  ADSChatSessionModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import ObjectMapper

class ADSChatSessionModel: ADSChatBaseModel {

    ///会话id<若会话为群聊,则sid为群聊gid, 若会话为私聊,则sid为对方uid>
    var sid: String?
    ///昵称
    var name: String?
    ///头像
    var avatar: String?
    ///未读消息数
    var unreadNum: String?
    ///是否是群聊 <group为数据库关键字, 故使用该单词替代>
    var cluster: Bool?
    ///是否开启消息免打扰 <ignore为数据库关键字, 故使用该单词替代>
    var silence: Bool?
    ///最后一条消息
    var lastMsg: String?
    ///最后一条消息时间 <该字段参与数据排序, 不要修改字段名, 为了避开数据库关键字, 故意拼错>
    var lastTimestmp: Int?
    
    ///时间戳排序
    func compareOtherModel(sessionModel: ADSChatSessionModel) -> ComparisonResult {
        return (self.lastTimestmp ?? 0) < (sessionModel.lastTimestmp ?? 0) ? ComparisonResult.orderedDescending : ComparisonResult.orderedAscending
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
