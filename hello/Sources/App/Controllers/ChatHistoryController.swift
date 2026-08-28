//
//  ChatHistoryController.swift
//
//  会话列表与历史消息查询（issue 02）
//

import Vapor
import Fluent

// 会话列表项中的联系人（对方用户）身份
struct SessionPeerDTO: Content {
    var userid: String
    var username: String
    var nickname: String
    var avatar: String
}

// 会话列表项中的最后一条消息（内容预览 + 时间）
struct SessionLastMessageDTO: Content {
    var content: String
    var msgType: String
    var fromSelf: Bool
    // Unix 秒（含小数部分）
    var createdAt: Double
}

// 会话列表项：联系人 + 最后一条消息
struct SessionSummaryDTO: Content {
    var peer: SessionPeerDTO
    var lastMessage: SessionLastMessageDTO
}

// 历史消息项
struct HistoryMessageDTO: Content {
    var id: String?
    var content: String
    var msgType: String
    var fromSelf: Bool
    var createdAt: Double
}

// 历史消息分页结果（messages 按时间正序）
struct HistoryResponseDTO: Content {
    var messages: [HistoryMessageDTO]
    var hasMore: Bool
}

enum ChatHistoryController {

    // GET /chat/sessions —— 会话列表：按联系人分组，按最后消息时间倒序
    static func sessions(req: Request) async throws -> [SessionSummaryDTO] {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        // 我参与的全部消息（发出 mine_userid = 我，收到 to_userid = 我），按时间倒序
        let messages = try await ChatMessage.query(on: req.db)
            .group(.or) { group in
                group.filter([.string("mine_userid")], .equal, myId)
                group.filter([.string("to_userid")], .equal, myId)
            }
            .sort([.string("created_at")], .descending)
            .all()

        // 联系人身份优先取 users 表（权威昵称/头像），无注册记录时回退消息内携带的身份
        var usersById: [String: User] = [:]
        let peerIds = Set(messages.map { $0.mine.userId == myId ? $0.to.userId : $0.mine.userId })
        let peerUUIDs = peerIds.compactMap { UUID(uuidString: $0) }
        if !peerUUIDs.isEmpty {
            let found = try await User.query(on: req.db).filter(\.$id ~~ peerUUIDs).all()
            usersById = Dictionary(uniqueKeysWithValues: found.compactMap { u in
                u.id.map { ($0.uuidString, u) }
            })
        }

        // 倒序遍历：每个联系人首次出现的那条即最新消息；出现顺序即会话排序
        var seen = Set<String>()
        var summaries: [SessionSummaryDTO] = []
        for message in messages {
            let sentByMe = message.mine.userId == myId
            let peerId = sentByMe ? message.to.userId : message.mine.userId
            guard !seen.contains(peerId) else { continue }
            seen.insert(peerId)
            summaries.append(makeSummary(last: message, sentByMe: sentByMe, peerId: peerId, usersById: usersById))
        }
        return summaries
    }

    private static func makeSummary(
        last: ChatMessage,
        sentByMe: Bool,
        peerId: String,
        usersById: [String: User]
    ) -> SessionSummaryDTO {
        let peer: SessionPeerDTO
        if let user = usersById[peerId] {
            peer = SessionPeerDTO(userid: peerId, username: user.account, nickname: user.nickname, avatar: user.avatar)
        } else if sentByMe {
            peer = SessionPeerDTO(userid: peerId, username: last.to.username, nickname: last.to.nickname, avatar: last.to.avatar)
        } else {
            peer = SessionPeerDTO(userid: peerId, username: last.mine.username, nickname: last.mine.nickname, avatar: last.mine.avatar)
        }
        return SessionSummaryDTO(
            peer: peer,
            lastMessage: SessionLastMessageDTO(
                content: last.mine.content,
                msgType: last.mine.msgType ?? "text",
                fromSelf: sentByMe,
                createdAt: last.createdAt?.timeIntervalSince1970 ?? 0
            )
        )
    }

    // GET /chat/history?peer=<userid>&limit=20&before=<unix秒>
    // —— 与指定联系人的双方消息按时间正序返回，支持向前翻页
    static func history(req: Request) async throws -> HistoryResponseDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        struct HistoryQuery: Content {
            var peer: String?
            var limit: Int?
            var before: Double?
        }
        let query = try req.query.decode(HistoryQuery.self)
        guard let peerId = query.peer?.trimmingCharacters(in: .whitespaces), !peerId.isEmpty else {
            throw Abort(.badRequest, reason: "缺少联系人参数 peer")
        }
        guard peerId != myId else {
            throw Abort(.badRequest, reason: "不能查询与自己账号的会话")
        }
        let limit = min(max(query.limit ?? 20, 1), 100)

        // 双方消息（我发给联系人、联系人发给我两个方向），按时间倒序取一页
        let builder = ChatMessage.query(on: req.db)
            .group(.or) { group in
                group.group(.and) { inner in
                    inner.filter([.string("mine_userid")], .equal, myId)
                    inner.filter([.string("to_userid")], .equal, peerId)
                }
                group.group(.and) { inner in
                    inner.filter([.string("mine_userid")], .equal, peerId)
                    inner.filter([.string("to_userid")], .equal, myId)
                }
            }
            .sort([.string("created_at")], .descending)
        if let before = query.before {
            builder.filter([.string("created_at")], .lessThan, before)
        }

        // 多取一条用于判断是否还有更早的历史
        let fetched = try await builder.limit(limit + 1).all()
        let hasMore = fetched.count > limit
        let page = Array(fetched.prefix(limit))

        // 对外按时间正序返回
        return HistoryResponseDTO(
            messages: page.reversed().map { message in
                HistoryMessageDTO(
                    id: message.id?.uuidString,
                    content: message.mine.content,
                    msgType: message.mine.msgType ?? "text",
                    fromSelf: message.mine.userId == myId,
                    createdAt: message.createdAt?.timeIntervalSince1970 ?? 0
                )
            },
            hasMore: hasMore
        )
    }
}
