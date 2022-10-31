//
//  ADSChatSessionModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import SQLite

@objcMembers class ADSChatSessionModel: ADSChatBaseModel {

    ///会话id<若会话为群聊,则sid为群聊gid, 若会话为私聊,则sid为对方uid>
    var sid: String = ""
    ///昵称
    var name: String = ""
    ///头像
    var avatar: String = ""
    ///未读消息数
    var unreadNum: String = ""
    ///是否是群聊 <group为数据库关键字, 故使用该单词替代>
    var cluster: Bool = false
    ///是否开启消息免打扰 <ignore为数据库关键字, 故使用该单词替代>
    var silence: Bool = false
    ///最后一条消息
    var lastMsg: String = ""
    ///最后一条消息时间 <该字段参与数据排序, 不要修改字段名, 为了避开数据库关键字, 故意拼错>
    var lastTimestmp: Int = 0
    
    ///时间戳排序
    func compareOtherModel(sessionModel: ADSChatSessionModel) -> ComparisonResult {
        return self.lastTimestmp < sessionModel.lastTimestmp ? ComparisonResult.orderedDescending : ComparisonResult.orderedAscending
    }

    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
//    required init?(map: Map) {
//        super.init(map: map)
////        // 检查 JSON 里是否有一定要有的 "name" 属性
////        if map.JSON["name"] == nil {
////            return nil
////        }
//    }
//
//    // Mappable
//    override func mapping(map: Map) { // 支持点语法
//        super.mapping(map: map)
////        username    <- map["username"]
////        age         <- map["age"]
////        weight      <- map["weight.head"]
////        array       <- map["arr"]
////        dictionary  <- map["dict"]
////        bestFriend  <- map["best_friend"]
////        friends     <- map["friends"]
////        birthday    <- (map["birthday"], DateTransform())
//    }
    
}


struct ChatSessionModelTable {
    private var db: Connection!
    private let table = Table("ChatSessionModelTable") //表名
    private let id = Expression<Int>("id") // 主键
    private let sid = Expression<String>("sid")
    private let name = Expression<String>("name")
    private let avatar = Expression<String>("avatar")
    private let unreadNum = Expression<String>("unreadNum")
    private let cluster = Expression<Bool>("cluster")
    private let silence = Expression<Bool>("silence")
    private let lastMsg = Expression<String>("lastMsg")
    private let lastTimestmp = Expression<Int>("lastTimestmp")
   
    init() {
        createdsqlite3()
    }
    
    // 创建数据库文件
    mutating func createdsqlite3() {
        // 设置数据库路径
        let sqlFilePath = NSHomeDirectory() + "/Documents/ChatSessionModelTable.sqlite3"
        do {
            db = try Connection(sqlFilePath) // 连接数据库
            // 创建表
            try db.run(table.create(block: { (table) in
                table.column(id, primaryKey: true)
                table.column(sid)
                table.column(name)
                table.column(avatar)
                table.column(unreadNum)
                table.column(cluster)
                table.column(silence)
                table.column(lastMsg)
                table.column(lastTimestmp)
            }))
        } catch {
            print("数据库表已经存在: \(error)")
        }
    }
    
    // 添加用户信息
    func insertSession(sessionModel: ADSChatSessionModel) {
        // 用户信息中没有ID就不存入数据库(被列为无效用户)
        guard sessionModel.sid.count > 0 else {
            print("没有ID信息,视为无效用户")
            return;
        }
        // 查找数据库中是否有该用户,如果有则执行修改操作
        guard readSession(sessionId: sessionModel.sid) == nil else {
            print("已存在改用户,接下来更新此用户数据")
            updateSession(sessionId: sessionModel.sid, sessionModel: sessionModel)
            return
        }
        let insert = table.insert(sid <- sessionModel.sid,
                                  name <- sessionModel.name,
                                  avatar <- sessionModel.avatar,
                                  unreadNum <- sessionModel.unreadNum,
                                  cluster <- sessionModel.cluster,
                                  silence <- sessionModel.silence,
                                  lastMsg <- sessionModel.lastMsg,
                                  lastTimestmp <- sessionModel.lastTimestmp)
        
        do {
            let num = try db.run(insert)
            print("insertUser\(num)")
        } catch {
            print("增加用户到数据库出错: \(error)")
        }
        
    }
    
    // 删除指定用户信息
    func deleteSession(sessionId: String) {
        let currSession = table.filter(sid == sessionId)
        do {
            let num = try db.run(currSession.delete())
            print("deleteUser\(num)")
        } catch {
            print("删除用户信息出错: \(error)")
        }
    }
    
    // 更新指定用户信息
    func updateSession(sessionId: String, sessionModel: ADSChatSessionModel) {
        let currSession = table.filter(sid == sessionId)
        let update = currSession.update(sid <- sessionModel.sid,
                                     name <- sessionModel.name,
                                     avatar <- sessionModel.avatar,
                                     unreadNum <- sessionModel.unreadNum,
                                     cluster <- sessionModel.cluster,
                                     silence <- sessionModel.silence,
                                     lastMsg <- sessionModel.lastMsg,
                                     lastTimestmp <- sessionModel.lastTimestmp)
        do {
            let num = try db.run(update)
            print("updateUser\(num)")
        } catch {
            print("updateUser\(error)")
        }
    }
    
    // 查询指定用户信息
    func readSession(sessionId: String) -> ADSChatSessionModel? {
        let sessionModel: ADSChatSessionModel = ADSChatSessionModel.init()
        for user in try! db.prepare(table) {
            if user[sid] == sessionId {
                sessionModel.sid = user[sid]
                sessionModel.name = user[name]
                sessionModel.avatar = user[avatar]
                sessionModel.unreadNum = user[unreadNum]
                sessionModel.cluster = user[cluster]
                sessionModel.silence = user[silence]
                sessionModel.lastMsg = user[lastMsg]
                sessionModel.lastTimestmp = user[lastTimestmp]
                return sessionModel
            }
        }
        return nil
    }
    
    // 查询所有用户信息
    func readAllSessions() -> [ADSChatSessionModel]? {
        var sessionArr: [ADSChatSessionModel] = [ADSChatSessionModel]()
        let sessionModel: ADSChatSessionModel = ADSChatSessionModel()
        for user in try! db.prepare(table) {
            sessionModel.sid = user[sid]
            sessionModel.name = user[name]
            sessionModel.avatar = user[avatar]
            sessionModel.unreadNum = user[unreadNum]
            sessionModel.cluster = user[cluster]
            sessionModel.silence = user[silence]
            sessionModel.lastMsg = user[lastMsg]
            sessionModel.lastTimestmp = user[lastTimestmp]
            sessionArr.append(sessionModel)
        }
        return sessionArr
    }
    
}
