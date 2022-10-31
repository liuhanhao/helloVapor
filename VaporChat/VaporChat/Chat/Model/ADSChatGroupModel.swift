//
//  ADSChatGroupModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import SQLite

@objcMembers class ADSChatGroupModel: ADSChatBaseModel {

    ///用户id
    var gid: String = ""
    ///用户昵称
    var name: String = ""
    ///用户头像 http://sqb.wowozhe.com/images/home/wx_appicon.png
    var avatar: String = ""
    ///聊天界面是否显示用户昵称
    var showName: Bool = false
    /// 群成员 成员ID 成员名称 成员头像
    var members: [[String:String]] = []
    
    override init() {
        super.init()
    }
    
    init(gid: String, name: String, avatar: String, showName: Bool = false, members: [[String:String]]) {
        super.init()
        self.gid = gid
        self.name = name
        self.avatar = avatar
        self.showName = showName
        self.members = members
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    
}

struct ChatGroupModelTable {
    private var db: Connection!
    private let table = Table("ChatGroupModelTable") //表名
    private let id = Expression<Int>("id") // 主键
    private let gid = Expression<String>("gid")
    private let name = Expression<String>("name")
    private let avatar = Expression<String>("avatar")
    private let showName = Expression<Bool>("showName")
    private let members = Expression<String>("members")
    
    init() {
        createdsqlite3()
    }

    // 创建数据库文件
    mutating func createdsqlite3() {
        // 设置数据库路径
        let sqlFilePath = NSHomeDirectory() + "/Documents/ChatGroupModelTable.sqlite3"
        do {
            db = try Connection(sqlFilePath) // 连接数据库
            // 创建表
            try db.run(table.create(block: { (table) in
                table.column(id, primaryKey: true)
                table.column(gid)
                table.column(name)
                table.column(avatar)
                table.column(showName)
                table.column(members)
            }))
        } catch {
            print("数据库表已经存在: \(error)")
        }
    }

    // 添加用户信息
    func insertGroup(groupModel: ADSChatGroupModel) {
        // 用户信息中没有ID就不存入数据库(被列为无效用户)
        guard groupModel.gid.count > 0 else {
            print("没有ID信息,视为无效用户")
            return;
        }
        // 查找数据库中是否有该用户,如果有则执行修改操作
        guard readGroup(groupId: groupModel.gid) == nil else {
            print("已存在改用户,接下来更新此用户数据")
            updateGroup(groupId: groupModel.gid, groupModel: groupModel)
            return
        }
        let insert = table.insert(gid <- groupModel.gid,
                                  name <- groupModel.name,
                                  avatar <- groupModel.avatar,
                                  showName <- groupModel.showName)

        do {
            let num = try db.run(insert)
            print("insertUser\(num)")
        } catch {
            print("增加用户到数据库出错: \(error)")
        }

    }

    // 删除指定用户信息
    func deleteGroup(userId: String) {
        let currGroup = table.filter(gid == userId)
        do {
            let num = try db.run(currGroup.delete())
            print("deleteUser\(num)")
        } catch {
            print("删除用户信息出错: \(error)")
        }
    }

    // 更新指定用户信息
    func updateGroup(groupId: String, groupModel: ADSChatGroupModel) {
        let currGroup = table.filter(gid == groupId)
        let update = currGroup.update(gid <- groupModel.gid,
                                      name <- groupModel.name,
                                      avatar <- groupModel.avatar,
                                      showName <- groupModel.showName)
        do {
            let num = try db.run(update)
            print("updateUser\(num)")
        } catch {
            print("updateUser\(error)")
        }
    }

    // 查询指定用户信息
    func readGroup(groupId: String) -> ADSChatGroupModel? {
        var groupModel: ADSChatGroupModel = ADSChatGroupModel.init()
        for group in try! db.prepare(table) {
            if group[gid] == groupId {
                groupModel.gid = group[gid]
                groupModel.name = group[name]
                groupModel.avatar = group[avatar]
                groupModel.showName = group[showName]
//                groupModel.showName = group[showName]
                return groupModel
            }
        }
        return nil
    }

    // 查询所有用户信息
    func readAllGroups() -> [ADSChatGroupModel]? {
        var groupsArr: [ADSChatGroupModel] = [ADSChatGroupModel]()
        var groupModel: ADSChatGroupModel = ADSChatGroupModel()
        for group in try! db.prepare(table) {
            groupModel.gid = group[gid]
            groupModel.name = group[name]
            groupModel.avatar = group[avatar]
            groupModel.showName = group[showName]
//            groupModel.members = group[members]
            groupsArr.append(groupModel)
        }
        return groupsArr
    }

}
