//
//  File.swift
//  
//
//  Created by admin on 2022/9/5.
//

import Vapor
import Fluent
import FluentSQLiteDriver

// @Enum 是 @Field 的一种特殊类型，用于将字符串可表示类型存储为原生数据库枚举。原生数据库枚举为你的数据库提供了额外的类型安全层，可能比原始枚举性能更好
// 消息聊天类型 String，Codable 协议。
enum MessageType: String, Codable {
    case single = "single" // 单聊
    case group = "group" // 群聊
    case system = "system" // 系统
}

/*****************   Mine   *********************************/
final class Mine: Fields {
    // 用户头像
    @Field(key: "avatar")
    var avatar: String
    
    // 消息内容
    @Field(key: "content")
    var content: String
    
    // 我的消息？
    @Field(key: "mine")
    var mine: Bool
    
    // 用户ID
    @Field(key: "userid")
    var userId: String
    
    // 账户
    @Field(key: "username")
    var username: String
    
    // 名称
    @Field(key: "nickname")
    var nickname: String
    
    init() {}
    init(avatar: String = "default", content: String, mine: Bool, userId: String, username: String, nickname: String) {
        self.avatar = avatar
        self.content = content
        self.mine = mine
        self.userId = userId
        self.username = username
        self.nickname = nickname
    }
}
/*****************   Mine   *********************************/

/*****************   To   *********************************/
final class To: Fields {
    // 用户头像
    @Field(key: "avatar")
    var avatar: String
    
    // 用户ID
    @Field(key: "userid")
    var userId: String
    
    // 账户
    @Field(key: "username")
    var username: String
    
    // 名称
    @Field(key: "nickname")
    var nickname: String
    
    init() {}
    init(avatar: String = "default", userId: String, username: String, nickname: String) {
        self.avatar = avatar
        self.userId = userId
        self.username = username
        self.nickname = nickname
    }
}
/*****************   To   *********************************/

// 模型默认遵循 Codable 协议。这意味着你可以通过添加 Content 协议将你的模型与 Vapor 的 content API 一起使用
final class ChatMessage: Model, Content {
    // 表或集合名。
    static let schema = "message"

    // 唯一标识符 由系统维护
    @ID(key: .id)
    var id: UUID?

    // 存储ISO 8601格式的时间戳
    // 此模型最后一次更新的时间。
    @Timestamp(key: "created_at", on: .create, format: .unix)
    var createdAt: Date?
    
    // 聊天类型存储为原生数据库枚举
    @Field(key: "type")
    var type: String
//    @Enum(key: "type")
//    var type: MessageType
    
    // 发送者
    @Group(key: "mine")
    var mine: Mine

    // 接受者
    @Group(key: "to")
    var to: To
    
    // 创建一个空实现用来映射。
    init() { }

    // 并设置所有属性。
    // 父标识符使用 $galaxy
    init(id: UUID? = nil, type: String, mine: Mine, to: To) {
        self.id = id
        self.type = type
        self.mine = mine
        self.to = to
//        self.$galaxy.id = galaxyID
    }
}

struct CreateMessage: AsyncMigration {
    // 为存储 Galaxy 模型准备数据库。
    func prepare(on database: Database) async throws {
        try await database.schema("message")
            .id()
            .field("created_at", .double)
            .field("type", .string)
            // mine
            .field("mine_avatar", .string)
            .field("mine_content", .string)
            .field("mine_mine", .bool)
            .field("mine_userid", .string)
            .field("mine_username", .string)
            .field("mine_nickname", .string)
            // to
            .field("to_avatar", .string)
            .field("to_userid", .string)
            .field("to_username", .string)
            .field("to_nickname", .string)
            .create()
    }

    // 可选地恢复 prepare 方法中所做的更改。
    func revert(on database: Database) async throws {
        try await database.schema("message").delete()
    }
}

// User.query(on: database).filter(\.$pet.$name == "Zizek").all()

