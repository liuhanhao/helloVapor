//
//  MessageRecallController.swift
//
//  消息撤回（B2 02）：把已发出的消息撤回来，对所有人同时生效。
//
//  撤回是软删——消息行留着，但对外不再返回原文（读取侧的替换在 ChatHistoryController）。
//  因为条数不变，未读计数一行都不用改（B2 决策记录第 3 条）。
//

import Vapor
import Fluent
import SwiftyJSON

// POST /chat/messages/:id/recall 的响应
struct RecallResponseDTO: Content {
    var id: String
    // Unix 秒（含小数部分）
    var recalledAt: Double
}

enum MessageRecallController {

    // POST /chat/messages/:id/recall —— 撤回消息。
    // 只有发送者能撤回（群消息的 to_id 是群 id，判定必须走 mine.userId）；
    // 群消息还要求撤回时仍是成员——退群即失去该群的消息处置权，撤回不开后门
    static func recall(req: Request) async throws -> RecallResponseDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString
        let db = req.db

        guard let rawId = req.parameters.get("id"), let messageId = UUID(uuidString: rawId) else {
            throw Abort(.badRequest, reason: "消息 ID 格式不正确")
        }
        guard let message = try await ChatMessage.find(messageId, on: db) else {
            throw Abort(.notFound, reason: "消息不存在")
        }
        guard message.mine.userId == myId else {
            throw Abort(.forbidden, reason: "只能撤回自己发出的消息")
        }
        // 已撤回过则幂等返回当前状态：不重复写库，也不重复推帧
        if let recalledAt = message.recalledAt {
            return RecallResponseDTO(id: messageId.uuidString, recalledAt: recalledAt)
        }

        // 扇出名单与发消息时严格一致：群给除自己外的成员，单聊给对端
        let isGroup = message.toType == RecipientType.group.rawValue
        var recipients: [String] = []
        if isGroup {
            try await GroupMember.requireMembership(groupId: message.toId, userId: myId, on: db)
            recipients = try await GroupMember.query(on: db)
                .filter(\.$groupId == message.toId)
                .all()
                .map { $0.userId }
                .filter { $0 != myId }
        } else {
            recipients = [message.toId]
        }

        let recalledAt = Date().timeIntervalSince1970
        message.recalledAt = recalledAt
        try await message.save(on: db)

        // 实时通知：撤回后对端界面还显示原文，等于撤回没生效。
        // 文案由服务端生成——收件方此时可能根本没加载这个会话，自己拼不出发送者昵称
        let who = message.mine.nickname.isEmpty ? "对方" : message.mine.nickname
        await WebSocketService.broadcast(
            [
                "type": "chatMessageRecalled",
                "data": [
                    "id": messageId.uuidString,
                    "recipientType": message.toType,
                    // 帧里的 recipientId 是「客户端该更新哪个会话」：
                    // 群是群 id；**单聊是发送者**——对接收方来说这个会话的收件主体就是对方。
                    // 与客户端 handleServerMessage 里 group ? to.userid : mine.userid 一致，
                    // 不能填 message.toId（那是接收方自己，客户端找不到这个会话）
                    "recipientId": isGroup ? message.toId : message.mine.userId,
                    // 中文里「你撤回了一条消息」不加空格；昵称后同样不加，保持一种格式
                    "content": "\(who)撤回了一条消息"
                ]
            ],
            to: recipients
        )

        return RecallResponseDTO(id: messageId.uuidString, recalledAt: recalledAt)
    }
}
