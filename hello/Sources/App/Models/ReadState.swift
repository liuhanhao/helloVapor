//
//  ReadState.swift
//
//  已读位点（未读计数 issue 01）：记录我在某个收件主体下已读到的位置。
//
//  未读数由它推出，不落库——`GET /chat/sessions` 在既有的内存遍历里累加得出。
//  为什么用服务端位点而不是前端本地计数，见 ADR-0003。
//

import Fluent
import Vapor

final class ReadState: Model, Content {
    static let schema = "read_states"

    @ID(key: .id)
    var id: UUID?

    // 位点归属的用户
    @Field(key: "user_id")
    var userId: String

    // 收件主体类型（RecipientType 的 rawValue）：user / group
    // 与 message.to_type 同义；键与会话列表内部的 "kind:peerId" 对齐
    @Field(key: "recipient_type")
    var recipientType: String

    // 收件主体 id：单聊为对方用户 id，群聊为群 id
    @Field(key: "recipient_id")
    var recipientId: String

    // 已读到的位置（Unix 秒，含小数部分）。不用 @Timestamp（那是创建时写一次），
    // 位点每次标记已读都要更新。时间表示与 ChatMessage.createdAt、
    // GroupMember.joinedAt 一致——三者会在同一段代码里比较
    @Field(key: "last_read_at")
    var lastReadAt: Double

    init() {}

    init(
        id: UUID? = nil,
        userId: String,
        recipientType: RecipientType,
        recipientId: String,
        lastReadAt: Double
    ) {
        self.id = id
        self.userId = userId
        self.recipientType = recipientType.rawValue
        self.recipientId = recipientId
        self.lastReadAt = lastReadAt
    }
}

extension ReadState {
    struct Migration: AsyncMigration {
        var name: String { "CreateReadState" }

        func prepare(on database: Database) async throws {
            try await database.schema("read_states")
                .id()
                .field("user_id", .string, .required)
                .field("recipient_type", .string, .required)
                .field("recipient_id", .string, .required)
                .field("last_read_at", .double, .required)
                // 一个用户在一个收件主体下只有一个位点，标记已读时 upsert
                .unique(on: "user_id", "recipient_type", "recipient_id")
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("read_states").delete()
        }
    }
}
