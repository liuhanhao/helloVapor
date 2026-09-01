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
    // 该消息是否已被撤回：客户端据此把预览/气泡换成提示样式
    var recalled: Bool
}

// 会话列表项：收件主体 + 最后一条消息，带形态标记区分单聊与群聊
struct SessionSummaryDTO: Content {
    // 会话形态：direct（单聊） / group（群聊）
    var kind: String
    var peer: SessionPeerDTO
    var lastMessage: SessionLastMessageDTO
    // 该会话我还没读的消息条数（由已读位点推出，不落库）
    var unreadCount: Int
    // 群成员数，仅群聊条目有值
    var memberCount: Int?
}

// POST /chat/read 的请求体：收件主体 id（单聊为对方用户 id，群聊为群 id）
struct MarkReadPayload: Content {
    var recipientId: String?
}

// POST /chat/read 的响应：写入后的位点。lastReadAt 为 Unix 秒（含小数部分）
struct MarkReadResponseDTO: Content {
    var recipientId: String
    var lastReadAt: Double
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
    // 是否已被撤回：content 此时是提示文案，不含原文
    var recalled: Bool
}

// 历史消息分页结果（messages 按时间正序）
struct HistoryResponseDTO: Content {
    var messages: [HistoryMessageDTO]
    var hasMore: Bool
}

// 搜索结果项：除消息本身外，还带「这条消息在哪个会话里说的」，前端才能跳转与显示
struct MessageSearchItemDTO: Content {
    var id: String
    var content: String
    var msgType: String
    var fromSelf: Bool
    // Unix 秒（含小数部分）
    var createdAt: Double
    var senderNickname: String
    // 定位用：点开结果要跳到这个收件主体
    var recipientType: String
    var recipientId: String
    // 展示用：群名或对方昵称
    var recipientName: String
}

// 搜索结果（messages 按时间倒序）
struct MessageSearchResponseDTO: Content {
    var messages: [MessageSearchItemDTO]
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
        // 入群时间统一成 Unix 秒：与消息时间、已读位点在同一套单位里比较
        let joinedAtByGroupId = Dictionary(uniqueKeysWithValues: joined.compactMap { row in
            row.joinedAt.map { (row.groupId, $0.timeIntervalSince1970) }
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

        // 已读位点：一次查全量建成 [key: lastReadAt]，键与下面循环里的 key 严格对齐，
        // 否则群会话会与同 id 的单聊串位。无记录即 lastReadAt = 0，该会话可见的消息全算未读
        let readStates = try await ReadState.query(on: db).filter(\.$userId == myId).all()
        let lastReadAtByKey = Dictionary(uniqueKeysWithValues: readStates.map { row in
            (sessionKey(row.recipientType, peerId: row.recipientId), row.lastReadAt)
        })

        // 倒序遍历：每个收件主体首次出现的那条即最新消息；出现顺序即会话排序。
        // 未读数在同一个循环里累加——消息已经取回，这里不新增任何查询
        var seen = Set<String>()
        var unreadByKey: [String: Int] = [:]
        var latest: [(kind: String, peerId: String, message: ChatMessage)] = []
        for message in messages {
            let kind = message.toType == RecipientType.group.rawValue ? "group" : "direct"
            // 群会话的收件主体是群（收发两个方向的 to 都是群）；单聊的收件主体是对方用户
            let peerId = kind == "group" || message.mine.userId == myId ? message.toId : message.mine.userId
            let createdAt = message.createdAt?.timeIntervalSince1970 ?? 0
            // 入群之前的群消息对自己不存在：否则未读数会和「点进去读不到的消息数」对不上
            if kind == "group", let joinedAt = joinedAtByGroupId[peerId], createdAt < joinedAt { continue }
            let key = sessionKey(kind, peerId: peerId)
            // 未读：自己发的消息不算，已读位点之前的消息不算
            if message.mine.userId != myId, createdAt > lastReadAtByKey[key] ?? 0 {
                unreadByKey[key, default: 0] += 1
            }
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
            let recalled = item.message.recalledAt != nil
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
                    content: recalled
                        ? recalledText(message: item.message, myId: myId)
                        : item.message.mine.content,
                    msgType: item.message.mine.msgType ?? "text",
                    fromSelf: sentByMe,
                    createdAt: item.message.createdAt?.timeIntervalSince1970 ?? 0,
                    recalled: recalled
                ),
                unreadCount: unreadByKey[sessionKey(item.kind, peerId: item.peerId)] ?? 0,
                memberCount: item.kind == "group" ? memberCounts[item.peerId] ?? 0 : nil
            )
        }
    }

    // 已撤回消息对外的提示文案（按查看者生成：自己发的说「你」）。
    // 原文**不返回**——撤回是「不再给你看」，不是从库里抹掉；替换只发生在构造 DTO 这里，
    // 模型层仍是真相
    private static func recalledText(message: ChatMessage, myId: String) -> String {
        let who = message.mine.userId == myId ? "你" : (message.mine.nickname.isEmpty ? "对方" : message.mine.nickname)
        // 中文里「你撤回了一条消息」不加空格；昵称后同样不加，保持一种格式
        return "\(who)撤回了一条消息"
    }

    // 会话的内部键：kind:peerId。位点表存的是 user / group，统一映射到同一套键上
    // （会话列表的 kind 是 direct / group），否则群会话会与同 id 的单聊串位
    private static func sessionKey(_ kindOrType: String, peerId: String) -> String {
        let kind = kindOrType == RecipientType.group.rawValue ? "group" : "direct"
        return "\(kind):\(peerId)"
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
                let recalled = message.recalledAt != nil
                return HistoryMessageDTO(
                    id: message.id?.uuidString,
                    // 已撤回的不再返回原文，换成按查看者生成的提示文案
                    content: recalled ? recalledText(message: message, myId: myId) : message.mine.content,
                    msgType: message.mine.msgType ?? "text",
                    fromSelf: message.mine.userId == myId,
                    createdAt: message.createdAt?.timeIntervalSince1970 ?? 0,
                    senderUserId: message.mine.userId,
                    senderNickname: message.mine.nickname,
                    senderAvatar: message.mine.avatar,
                    recalled: recalled
                )
            },
            hasMore: hasMore
        )
    }

    // GET /chat/messages/search?q=<关键词>&limit=20&offset=0
  // —— 按内容检索我可见的消息，按时间倒序。可见性规则与 /chat/history 严格一致：
  // 单聊两个方向、群要求成员身份且只看到入群之后。搜索不能成为绕过退群/入群时间的旁路
  static func search(req: Request) async throws -> MessageSearchResponseDTO {
    let user = try req.auth.require(User.self)
    let myId = try user.requireID().uuidString
    let db = req.db

    struct SearchQuery: Content {
      var q: String?
      var limit: Int?
      var offset: Int?
    }
    let query = try req.query.decode(SearchQuery.self)
    let keyword = query.q?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !keyword.isEmpty else {
      throw Abort(.badRequest, reason: "缺少搜索关键词 q")
    }
    let limit = min(max(query.limit ?? 20, 1), 50)
    let offset = max(query.offset ?? 0, 0)

    // 我加入的群与入群时间：群消息只在这个范围内可见
    let joined = try await GroupMember.query(on: db).filter(\.$userId == myId).all()
    let joinedAtByGroupId = Dictionary(uniqueKeysWithValues: joined.compactMap { row in
      row.joinedAt.map { (row.groupId, $0.timeIntervalSince1970) }
    })

    let builder = ChatMessage.query(on: db)
    builder.group(.or) { or in
      or.group(.and) { direct in
        direct.filter([.string("to_type")], .equal, RecipientType.user.rawValue)
        direct.group(.or) { mine in
          mine.filter([.string("mine_userid")], .equal, myId)
          mine.filter([.string("to_id")], .equal, myId)
        }
      }
      // 每个群的入群时间不同，只能逐个群加条件；已退的群自然不在 joined 里
      for (groupId, joinedAt) in joinedAtByGroupId {
        or.group(.and) { group in
          group.filter([.string("to_type")], .equal, RecipientType.group.rawValue)
          group.filter(\ChatMessage.$toId == groupId)
          group.filter([.string("created_at")], .greaterThanOrEqual, joinedAt)
        }
      }
    }
    // 已撤回的消息不能搜到原文——撤回是软删，库里仍是原文。
    // recalledAt 是顶层 @OptionalField，key path 可用，生成 recalled_at IS NULL
    builder.filter(\.$recalledAt == nil)
    // 已知上限：关键词里的 % 与 _ 未做转义，LIKE 会把它俩当通配符（搜「100%」会命中过多）。
    // 为它写裸 SQL 拼 ESCAPE 子句不划算，等真有人抱怨再说
    builder.filter([.string("mine_content")], .contains(inverse: false, .anywhere), keyword)
    builder.sort([.string("created_at")], .descending)

    // 媒体消息在 Swift 侧剔除后再分页（见下方说明），所以这里多取一些作为候选
    let fetched = try await builder.limit(offset + limit + 1).all()
    let candidates = fetched.filter { message in
      // 媒体消息的 content 是文件 URL，拿它做 LIKE 只会搜出噪音。
      // 不在 SQL 侧用 NOT IN 过滤：mine_msgType 旧数据为 NULL（按 text 解读），
      // NULL NOT IN (...) 求值为 NULL，会把老的文本消息一起排除掉
      switch message.mine.msgType ?? "text" {
      case "image", "audio", "video": return false
      default: return true
      }
    }
    let page = Array(candidates.dropFirst(offset).prefix(limit))
    let hasMore = candidates.count > offset + limit

    // 收件主体：群为群 id；单聊为对方（我发的填 to_id，对方发的填 mine_userid）
    let items = page.map { message -> (message: ChatMessage, recipientId: String) in
      let isGroup = message.toType == RecipientType.group.rawValue
      return (message, isGroup || message.mine.userId == myId ? message.toId : message.mine.userId)
    }
    // 收件主体身份沿用 sessions 的做法：群取 groups 表，单聊优先取 users 表
    let usersByPeerId = try await usersById(
      on: db,
      ids: items.filter { $0.message.toType != RecipientType.group.rawValue }.map { $0.recipientId }
    )
    let groupsByGroupId = try await groupsById(
      on: db,
      ids: items.filter { $0.message.toType == RecipientType.group.rawValue }.map { $0.recipientId }
    )

    return MessageSearchResponseDTO(
      messages: items.map { item -> MessageSearchItemDTO in
        let isGroup = item.message.toType == RecipientType.group.rawValue
        let sentByMe = item.message.mine.userId == myId
        let name: String
        if isGroup {
          name = groupsByGroupId[item.recipientId]?.name ?? item.recipientId
        } else if let user = usersByPeerId[item.recipientId] {
          name = user.nickname
        } else if sentByMe {
          // 我发出去的：对方身份在 to 里（无注册记录时的回退）
          name = item.message.to.nickname.isEmpty ? item.message.to.username : item.message.to.nickname
        } else {
          name = item.message.mine.nickname
        }
        return MessageSearchItemDTO(
          id: item.message.id?.uuidString ?? "",
          content: item.message.mine.content,
          msgType: item.message.mine.msgType ?? "text",
          fromSelf: sentByMe,
          createdAt: item.message.createdAt?.timeIntervalSince1970 ?? 0,
          senderNickname: item.message.mine.nickname,
          recipientType: item.message.toType,
          recipientId: item.recipientId,
          recipientName: name
        )
      },
      hasMore: hasMore
    )
  }

  // POST /chat/read —— 标记已读：把我在该收件主体下的已读位点推到「现在」，
    // 会话列表据此算未读数。收件主体的判定与 /chat/history 一致：命中群即群（非成员 403），
    // 否则按单聊（不能是自己）。位点按 (user, 收件主体) upsert
    static func markRead(req: Request) async throws -> MarkReadResponseDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString
        let db = req.db

        let payload = try req.content.decode(MarkReadPayload.self)
        guard let recipientId = payload.recipientId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !recipientId.isEmpty
        else {
            throw Abort(.badRequest, reason: "缺少收件主体参数 recipientId")
        }

        let type: RecipientType
        if let uuid = UUID(uuidString: recipientId), try await Group.find(uuid, on: db) != nil {
            // 非成员不能给一个自己看不到的会话标记已读，否则位点会掩盖它本该看到的未读
            try await GroupMember.requireMembership(groupId: recipientId, userId: myId, on: db)
            type = .group
        } else {
            guard recipientId != myId else {
                throw Abort(.badRequest, reason: "不能标记与自己账号的会话，未读只针对别人发来的消息")
            }
            type = .user
        }

        let lastReadAt = Date().timeIntervalSince1970
        let existing = try await ReadState.query(on: db)
            .filter(\.$userId == myId)
            .filter([.string("recipient_type")], .equal, type.rawValue)
            .filter(\.$recipientId == recipientId)
            .first()
        if let existing {
            existing.lastReadAt = lastReadAt
            try await existing.save(on: db)
        } else {
            try await ReadState(
                userId: myId,
                recipientType: type,
                recipientId: recipientId,
                lastReadAt: lastReadAt
            ).save(on: db)
        }
        return MarkReadResponseDTO(recipientId: recipientId, lastReadAt: lastReadAt)
    }
}
