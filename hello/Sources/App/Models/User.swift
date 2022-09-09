//
//  File.swift
//  
//
//  Created by admin on 2022/9/5.
//

import Fluent
import Vapor

// User表格
final class User: Model, Content {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "avatar")
    var avatar: String
    
    @Field(key: "nickname")
    var nickname: String
    
    @Field(key: "account")
    var account: String

    @Field(key: "password_hash")
    var passwordHash: String

    init() { }

    init(id: UUID? = nil, avatar: String, nickname: String, account: String, passwordHash: String) {
        self.id = id
        self.avatar = avatar
        self.nickname = nickname
        self.account = account
        self.passwordHash = passwordHash
    }
}
// 数据库迁移
extension User {
    struct Migration: AsyncMigration {
        var name: String { "CreateUser" }

        func prepare(on database: Database) async throws {
            try await database.schema("users")
                .id()
                .field("avatar", .string, .required)
                .field("nickname", .string, .required)
                .field("account", .string, .required)
                .field("password_hash", .string, .required)
                .unique(on: "account")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("users").delete()
        }
    }
}

// registered路由的模型
extension User {
    struct Create: Content {
        var avatar: String
        var nickname: String
        var account: String
        var password: String
        var confirmPassword: String
    }
}

// 可认证的模型
extension User: ModelAuthenticatable {
    static let usernameKey = \User.$account
    static let passwordHashKey = \User.$passwordHash

    // 此方法是 Basic Auth 认证 的密码校验方法
    // usernameKey passwordHashKey 与 User中的 email 以及 passwordHash相互关联
    func verify(password: String) throws -> Bool {
        print(self.passwordHash,password)
        let result = try Bcrypt.verify(password, created: self.passwordHash)
        return result
    }
}
// 为 User 添加一个用于生成新令牌的方法。此方法将在登录时使用
extension User {
    func generateToken() throws -> UserToken {
        try .init(
            value: [UInt8].random(count: 16).base64,
            userID: self.requireID()
        )
    }
}

