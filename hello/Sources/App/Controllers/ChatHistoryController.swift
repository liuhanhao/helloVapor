//
//  ChatHistoryController.swift
//
//  会话列表与历史消息查询（issue 02）
//

import Vapor
import Fluent

// 会话列表项中的收件主体身份：单聊为对方用户，群聊为群
// （群聊时 userid 是群 id、nickname 是群名、avatar 是群头像，username 无意义为空串）
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

// 会话列表项：收件主体 + 最后一条消息，带形态标记区分单聊与群聊
struct SessionSummaryDTO: Content {
    // 会话形态：direct（单聊） / group（群聊）
    var kind: String
    var peer: SessionPeerDTO
    var lastMessage: SessionLastMessageDTO
    // 群成员数，仅群聊条目有值
    var memberCount: Int?
}

// 历史消息项
struct HistoryMessageDTO: Content {
    var id: String?
    var content: String
    var msgType: String
    var fromSelf: Bool
    var createdAt: Double
    // 发送者身份：群聊要靠它渲染昵称与头像（单聊不需要，但一并返回）
    var senderUserId: String
    var senderNickname: String
    var senderAvatar: String
}

// 历史消息分页结果（messages 按时间正序）
struct HistoryResponseDTO: Content {
    var messages: [HistoryMessageDTO]
    var hasMore: Bool
}

enum ChatHistoryController {

    // GET /chat/sessions —— 会话列表：单聊与群聊条目统一返回，按最后消息时间倒序
    static func sessions(req: Request) async throws -> [SessionSummaryDTO] {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString
        let db = req.db

        // 我加入的群：群会话只在我仍是成员期间可见（退群即失去该群访问权），
        // 且只暴露入群之后的消息（重新加入不回溯旧消息）
        let joined = try await GroupMember.query(on: db).filter(\.$userId == myId).all()
        let myGroupIds = Array(Set(joined.map { $0.groupId }))
        let joinedAtByGroupId = Dictionary(uniqueKeysWithValues: joined.compactMap { row in
            row.joinedAt.map { (row.groupId, $0) }
        })

        // 我参与的会话消息：单聊（我发出 / 我收到）+ 我所在群的全部群消息，按时间倒序
        let messages = try await ChatMessage.query(on: db)
            .group(.or) { or in
                or.group(.and) { direct in
                    direct.filter([.string("to_type")], .equal, RecipientType.user.rawValue)
                    direct.group(.or) { mine in
                        mine.filter([.string("mine_userid")], .equal, myId)
                        mine.filter([.string("to_id")], .equal, myId)
                    }
                }
                if !myGroupIds.isEmpty {
                    or.group(.and) { group in
                        group.filter([.string("to_type")], .equal, RecipientType.group.rawValue)
                        group.filter(\ChatMessage.$toId ~~ myGroupIds)
                    }
                }
            }
            .sort([.string("created_at")], .descending)
            .all()

        // 倒序遍历：每个收件主体首次出现的那条即最新消息；出现顺序即会话排序
        var seen = Set<String>()
        var latest: [(kind: String, peerId: String, message: ChatMessage)] = []
        for message in messages {
            let kind = message.toType == RecipientType.group.rawValue ? "group" : "direct"
            // 群会话的收件主体是群（收发两个方向的 to 都是群）；单聊的收件主体是对方用户
            let peerId = kind == "group" || message.mine.userId == myId ? message.toId : message.mine.userId
            // 入群之前的群消息对自己不存在：否则会话列表会预览一条点进去读不到的消息
            if kind == "group",
               let joinedAt = joinedAtByGroupId[peerId],
               let createdAt = message.createdAt,
               createdAt < joinedAt { continue }
            let key = "\(kind):\(peerId)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            latest.append((kind, peerId, message))
        }

        // 收件主体身份：单聊优先取 users 表（权威昵称/头像），无注册记录时回退消息内携带的身份；
        // 群聊取 groups 表（群名/头像）并附成员数
        let usersById = try await usersById(on: db, ids: latest.filter { $0.kind == "direct" }.map { $0.peerId })
        let groupIds = latest.filter { $0.kind == "group" }.map { $0.peerId }
        let groupsById = try await groupsById(on: db, ids: groupIds)
        let memberCounts = groupIds.isEmpty ? [:] : try await GroupMember.counts(on: db, groupIds: groupIds)

        return latest.compactMap { item -> SessionSummaryDTO? in
            let sentByMe = item.message.mine.userId == myId
            let peer: SessionPeerDTO
            if item.kind == "group" {
                guard let group = groupsById[item.peerId] else { return nil }
                peer = SessionPeerDTO(userid: item.peerId, username: "", nickname: group.name, avatar: group.avatar)
            } else if let user = usersById[item.peerId] {
                peer = SessionPeerDTO(userid: item.peerId, username: user.account, nickname: user.nickname, avatar: user.avatar)
            } else if sentByMe {
                peer = SessionPeerDTO(userid: item.peerId, username: item.message.to.username, nickname: item.message.to.nickname, avatar: item.message.to.avatar)
            } else {
                peer = SessionPeerDTO(userid: item.peerId, username: item.message.mine.username, nickname: item.message.mine.nickname, avatar: item.message.mine.avatar)
            }
            return SessionSummaryDTO(
                kind: item.kind,
                peer: peer,
                lastMessage: SessionLastMessageDTO(
                    content: item.message.mine.content,
                    msgType: item.message.mine.msgType ?? "text",
                    fromSelf: sentByMe,
                    createdAt: item.message.createdAt?.timeIntervalSince1970 ?? 0
                ),
                memberCount: item.kind == "group" ? memberCounts[item.peerId] ?? 0 : nil
            )
        }
    }

    private static func usersById(on db: Database, ids: [String]) async throws -> [String: User] {
        let uuids = ids.compactMap { UUID(uuidString: $0) }
        guard !uuids.isEmpty else { return [:] }
        let users = try await User.query(on: db).filter(\.$id ~~ uuids).all()
        return Dictionary(uniqueKeysWithValues: users.compactMap { user in
            user.id.map { ($0.uuidString, user) }
        })
    }

    private static func groupsById(on db: Database, ids: [String]) async throws -> [String: Group] {
        let uuids = ids.compactMap { UUID(uuidString: $0) }
        guard !uuids.isEmpty else { return [:] }
        let groups = try await Group.query(on: db).filter(\.$id ~~ uuids).all()
        return Dictionary(uniqueKeysWithValues: groups.compactMap { group in
            group.id.map { ($0.uuidString, group) }
        })
    }

    // GET /chat/history?peer=<用户 id 或群 id>&limit=20&before=<unix秒>
    // —— peer 是收件主体：命中群则按群历史返回（非成员被拒），否则按单聊历史返回，
    // 两者都按时间正序、支持向前翻页
    static func history(req: Request) async throws -> HistoryResponseDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString
        let db = req.db

        struct HistoryQuery: Content {
            var peer: String?
            var limit: Int?
            var before: Double?
        }
        let query = try req.query.decode(HistoryQuery.self)
        guard let peerId = query.peer?.trimmingCharacters(in: .whitespaces), !peerId.isEmpty else {
            throw Abort(.badRequest, reason: "缺少联系人参数 peer")
        }
        let limit = min(max(query.limit ?? 20, 1), 100)

        // peer 命中群即按群历史处理，否则按单聊处理——群 id 与用户 id 同为 UUID，靠查表区分
        var isGroup = false
        if let uuid = UUID(uuidString: peerId) {
            isGroup = try await Group.find(uuid, on: db) != nil
        }
        // 非成员查群历史直接拒绝，不返回空数组糊弄过去（退群即失去该群访问权）；
        // 拿到的入群时间是「能看到哪些群消息」的起点——重新加入不回溯旧消息
        var joinedAt: Double = 0
        if isGroup {
            joinedAt = try await GroupMember.requireMembership(groupId: peerId, userId: myId, on: db)
                .joinedAt?.timeIntervalSince1970 ?? 0
        } else {
            guard peerId != myId else {
                throw Abort(.badRequest, reason: "不能查询与自己账号的会话")
            }
        }

        let builder = ChatMessage.query(on: db)
        if isGroup {
            builder.filter([.string("to_type")], .equal, RecipientType.group.rawValue)
                   .filter(\ChatMessage.$toId == peerId)
                   .filter([.string("created_at")], .greaterThanOrEqual, joinedAt)
        } else {
            // 单聊：双方两个方向的消息
            builder.group(.or) { group in
                group.group(.and) { inner in
                    inner.filter([.string("to_type")], .equal, RecipientType.user.rawValue)
                    inner.filter([.string("mine_userid")], .equal, myId)
                    inner.filter([.string("to_id")], .equal, peerId)
                }
                group.group(.and) { inner in
                    inner.filter([.string("to_type")], .equal, RecipientType.user.rawValue)
                    inner.filter([.string("mine_userid")], .equal, peerId)
                    inner.filter([.string("to_id")], .equal, myId)
                }
            }
        }
        builder.sort([.string("created_at")], .descending)
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
                    createdAt: message.createdAt?.timeIntervalSince1970 ?? 0,
                    senderUserId: message.mine.userId,
                    senderNickname: message.mine.nickname,
                    senderAvatar: message.mine.avatar
                )
            },
            hasMore: hasMore
        )
    }
}
