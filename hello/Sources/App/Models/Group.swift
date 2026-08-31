//
//  Group.swift
//
//  群（issue 01：群聊数据模型）
//
//  群是一个持久实体：有名称、头像、创建者和成员列表。群本身**不是**会话——
//  它是会话的参与方容器（词汇定义见根目录 CONTEXT.md）。
//
//  本文件只落地模型与表结构：群的读写接口在后续 issue 给出，
//  在此之前没有任何代码路径会触碰这两张表。
//

import Fluent
import Vapor

final class Group: Model, Content {
    static let schema = "groups"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "avatar")
    var avatar: String

    // 创建者的 userid
    @Field(key: "owner_id")
    var ownerId: String

    @Timestamp(key: "created_at", on: .create, format: .unix)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, name: String, avatar: String = "default", ownerId: String) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.ownerId = ownerId
    }
}

extension Group {
    struct Migration: AsyncMigration {
        var name: String { "CreateGroup" }

        func prepare(on database: Database) async throws {
            try await database.schema("groups")
                .id()
                .field("name", .string, .required)
                .field("avatar", .string, .required)
                .field("owner_id", .string, .required)
                .field("created_at", .double)
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("groups").delete()
        }
    }
}
