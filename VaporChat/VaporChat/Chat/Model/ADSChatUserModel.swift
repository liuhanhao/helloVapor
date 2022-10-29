//
//  ADSChatUserModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import SQLite

@objcMembers class ADSChatUserModel: ADSChatBaseModel {

    ///默认登录用户
    let shareInfo = ADSChatUserModel.init(uid: "00001",
                                          name: "无敌是多么的寂寞",
                                          avatar: "http://sqb.wowozhe.com/images/home/wx_appicon.png")
    ///用户id
    var uid: String = ""
    ///用户昵称
    var name: String = ""
    ///用户头像 http://sqb.wowozhe.com/images/home/wx_appicon.png
    var avatar: String = ""
    ///聊天界面是否显示用户昵称
    var showName: Bool = false
    
    override init() {
        super.init()
    }
    
    init(uid: String, name: String, avatar: String, showName: Bool = false) {
        super.init()
        self.uid = uid
        self.name = name
        self.avatar = avatar
        self.showName = showName
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
}

struct ChatUserModelTable {
    private var db: Connection!
    private let table = Table("ChatUserModelTable") //表名
    private let id = Expression<Int>("id") // 主键
    private let uid = Expression<String>("uid")
    private let name = Expression<String>("name")
    private let avatar = Expression<String>("avatar")
    private let showName = Expression<Bool>("showName")
    
    init() {
        createdsqlite3()
    }
    
    // 创建数据库文件
    mutating func createdsqlite3() {
        // 设置数据库路径
        let sqlFilePath = NSHomeDirectory() + "/Documents/ChatUserModelTable.sqlite3"
        do {
            db = try Connection(sqlFilePath) // 连接数据库
            // 创建表
            try db.run(table.create(block: { (table) in
                table.column(id, primaryKey: true)
                table.column(uid)
                table.column(name)
                table.column(avatar)
                table.column(showName)
            }))
        } catch {
            print("创建数据库出错: \(error)")
        }
    }
    
    // 添加用户信息
    func insertUser(userModel: ADSChatUserModel) {
        // 用户信息中没有ID就不存入数据库(被列为无效用户)
        guard userModel.uid.count > 0 else {
            print("没有ID信息,视为无效用户")
            return;
        }
        // 查找数据库中是否有该用户,如果有则执行修改操作
        guard readUser(userId: userModel.uid) == nil else {
            print("已存在改用户,接下来更新此用户数据")
            updateUser(userId: userModel.uid, userModel: userModel)
            return
        }
        let insert = table.insert(uid <- userModel.uid,
                                  name <- userModel.name,
                                  avatar <- userModel.avatar,
                                  showName <- userModel.showName)
        
        do {
            let num = try db.run(insert)
            print("insertUser\(num)")
        } catch {
            print("增加用户到数据库出错: \(error)")
        }
        
    }
    
    // 删除指定用户信息
    func deleteUser(userId: String) {
        let currUser = table.filter(uid == userId)
        do {
            let num = try db.run(currUser.delete())
            print("deleteUser\(num)")
        } catch {
            print("删除用户信息出错: \(error)")
        }
    }
    
    // 更新指定用户信息
    func updateUser(userId: String, userModel: ADSChatUserModel) {
        let currUser = table.filter(uid == userId)
        let update = currUser.update(uid <- userModel.uid,
                                     name <- userModel.name,
                                     avatar <- userModel.avatar,
                                     showName <- userModel.showName)
        do {
            let num = try db.run(update)
            print("updateUser\(num)")
        } catch {
            print("updateUser\(error)")
        }
    }
    
    // 查询指定用户信息
    func readUser(userId: String) -> ADSChatUserModel? {
        let userModel: ADSChatUserModel = ADSChatUserModel.init()
        for user in try! db.prepare(table) {
            if user[uid] == userId {
                userModel.uid = user[uid]
                userModel.name = user[name]
                userModel.avatar = user[avatar]
                userModel.showName = user[showName]
                return userModel
            }
        }
        return nil
    }
    
    // 查询所有用户信息
    func readAllUsers() -> [ADSChatUserModel]? {
        var usersArr: [ADSChatUserModel] = [ADSChatUserModel]()
        let userModel: ADSChatUserModel = ADSChatUserModel()
        for user in try! db.prepare(table) {
            userModel.uid = user[uid]
            userModel.name = user[name]
            userModel.avatar = user[avatar]
            userModel.showName = user[showName]
            usersArr.append(userModel)
        }
        return usersArr
    }
    
    // 事务的写法
    func transaction(userId: String) -> ADSChatUserModel? {
        
        var model:ADSChatUserModel? = nil
        do {
            try db.transaction {
                model = self.readUser(userId: userId)
            }
        }
        catch {
            print("updateUser\(error)")
        }
        
        return model
    }
}
