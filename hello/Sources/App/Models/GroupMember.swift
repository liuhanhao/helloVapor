//
//  GroupMember.swift
//
//  群成员（issue 01：群聊数据模型）
//
//  成员是**显式记录**的关系：不能像「联系人」那样由历史消息推导，
//  否则无法区分「已退群」与「还没说过话」——两种情况下都没有消息。
//

import Fluent
import Vapor

final class GroupMember: Model, Content {
    static let schema = "group_members"

    @ID(key: .id)
    var id: UUID?

    // 所属群的 id（Group.id 的 uuid 字符串）
    @Field(key: "group_id")
    var groupId: String

    // 成员的 userid
    @Field(key: "user_id")
    var userId: String

    @Timestamp(key: "joined_at", on: .create, format: .unix)
    var joinedAt: Date?

    init() {}

    init(id: UUID? = nil, groupId: String, userId: String) {
        self.id = id
        self.groupId = groupId
        self.userId = userId
    }
}

extension GroupMember {

    // 群成员关系的两处共用查询：WS 发消息、查群历史、会话列表都要先回答「我是不是这个群的成员」

    /// 非成员一律拒绝：退群即失去该群访问权（群聊规格决策记录第 4 条）。
    /// 返回成员记录：它的入群时间是「能看到哪些群消息」的起点
    @discardableResult
    static func requireMembership(groupId: String, userId: String, on db: Database) async throws -> GroupMember {
        guard let membership = try await GroupMember.query(on: db)
            .filter(\.$groupId == groupId)
            .filter(\.$userId == userId)
            .first()
        else {
            throw Abort(.forbidden, reason: "您不是该群成员，无法访问该群信息")
        }
        return membership
    }

    /// 群 id -> 成员数（一次查询批量取，会话列表要给每个群条目带成员数）
    static func counts(on db: Database, groupIds: [String]) async throws -> [String: Int] {
        let rows = try await GroupMember.query(on: db).filter(\.$groupId ~~ groupIds).all()
        return rows.reduce(into: [:]) { counts, row in
            counts[row.groupId, default: 0] += 1
        }
    }

    struct Migration: AsyncMigration {
        var name: String { "CreateGroupMember" }

        func prepare(on database: Database) async throws {
            try await database.schema("group_members")
                .id()
                .field("group_id", .string, .required)
                .field("user_id", .string, .required)
                .field("joined_at", .double)
                .unique(on: "group_id", "user_id")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("group_members").delete()
        }
    }
}
