//
//  File.swift
//  
//
//  Created by admin on 2022/9/5.
//

import Fluent
import Vapor

// 创建UserToken表
final class UserToken: Model, Content {
    static let schema = "user_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Parent(key: "user_id")
    var user: User

    init() { }

    init(id: UUID? = nil, value: String, userID: User.IDValue) {
        self.id = id
        self.value = value
        self.$user.id = userID
    }
}

// 迁移
extension UserToken {
    struct Migration: AsyncMigration {
        var name: String { "CreateUserToken" }

        func prepare(on database: Database) async throws {
            try await database.schema("user_tokens")
                .id()
                .field("value", .string, .required)
                .field("user_id", .uuid, .required, .references("users", "id"))
                .unique(on: "value")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("user_tokens").delete()
        }
    }
}

// 如果这是 false，令牌将从数据库中删除，用户将不被验证。为了简单起见，我们将把这个硬编码为 true，使这些标记永远存在
extension UserToken: ModelTokenAuthenticatable {
    static let valueKey = \UserToken.$value
    static let userKey = \UserToken.$user

    // 验证token是否有效 暂时这里写一直有效
    var isValid: Bool {
        true
    }
}
