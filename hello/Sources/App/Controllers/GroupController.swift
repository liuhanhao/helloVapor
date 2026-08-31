//
//  GroupController.swift
//
//  建群与成员管理（群聊 02）
//
//  权限规则按规格定死，不做扩展：任何成员可拉人入群；只有创建者可改群名与头像；
//  只能退自己，不能踢别人。不做管理员、不做群主转让、不做禁言、不做群解散。
//

import Vapor
import Fluent

// 群列表项 / 群详情：含成员数，供前端展示「群聊(5)」这类信息
struct GroupSummaryDTO: Content {
    var id: String
    var name: String
    var avatar: String
    // 创建者的 userid
    var ownerId: String
    var memberCount: Int
    // Unix 秒（含小数部分）
    var createdAt: Double
}

// 群成员项：身份取自 users 表（权威昵称/头像）
struct GroupMemberDTO: Content {
    var userid: String
    var username: String
    var nickname: String
    var avatar: String
    // Unix 秒（含小数部分）
    var joinedAt: Double
}

// POST /chat/groups 请求体：memberIds 不含创建者（创建者自动入群）
struct CreateGroupPayload: Content {
    var name: String
    var avatar: String?
    var memberIds: [String]?
}

// POST /chat/groups/:id/members 请求体
struct AddMemberPayload: Content {
    var userId: String
}

// PATCH /chat/groups/:id 请求体：只改传了的字段
struct UpdateGroupPayload: Content {
    var name: String?
    var avatar: String?
}

enum GroupController {

    // 群成员数上限：扇出是在线成员逐个推送，规模直接决定一条消息的写放大倍数
    static let maxMemberCount = 200

    // POST /chat/groups —— 建群：创建者自动成为成员且为 owner
    static func create(req: Request) async throws -> GroupSummaryDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        let payload = try req.content.decode(CreateGroupPayload.self)
        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw Abort(.badRequest, reason: "群名称不能为空")
        }

        // 入参里带上创建者本人只是重复，不是错误
        let candidates = (payload.memberIds ?? []).filter {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) != myId
        }
        // 先校验上限，避免为一个注定失败的请求去查 200 条用户
        try guardMemberCount(current: 1, adding: candidates.count)

        let invitees = try await validateUserIds(candidates, on: req.db)

        let avatar = payload.avatar?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let group = Group(name: name, avatar: avatar.isEmpty ? "default" : avatar, ownerId: myId)
        try await group.save(on: req.db)

        let groupId = try group.requireID().uuidString
        try await GroupMember(groupId: groupId, userId: myId).save(on: req.db)
        for inviteeId in invitees {
            try await GroupMember(groupId: groupId, userId: inviteeId).save(on: req.db)
        }

        return try summary(group: group, memberCount: 1 + invitees.count)
    }

    // GET /chat/groups —— 我加入的群，按创建时间倒序
    static func list(req: Request) async throws -> [GroupSummaryDTO] {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        let joined = try await GroupMember.query(on: req.db).filter(\.$userId == myId).all()
        let groupIds = joined.map { $0.groupId }
        guard !groupIds.isEmpty else { return [] }

        let groups = try await Group.query(on: req.db)
            .filter(\.$id ~~ groupIds.compactMap { UUID(uuidString: $0) })
            .all()
        let counts = try await GroupMember.counts(on: req.db, groupIds: groupIds)

        return try groups
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .compactMap { group -> GroupSummaryDTO? in
                guard let id = group.id?.uuidString else { return nil }
                return try summary(group: group, memberCount: counts[id] ?? 0)
            }
    }

    // GET /chat/groups/:id/members —— 群成员列表；非成员访问被拒
    static func members(req: Request) async throws -> [GroupMemberDTO] {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        let groupId = try requireGroupId(req)
        _ = try await requireGroup(req, groupId: groupId)
        try await GroupMember.requireMembership(groupId: groupId, userId: myId, on: req.db)

        let rows = try await GroupMember.query(on: req.db)
            .filter(\.$groupId == groupId)
            .sort(\.$joinedAt, .ascending)
            .all()
        let users = try await usersById(on: req.db, ids: rows.map { $0.userId })

        return rows.compactMap { row -> GroupMemberDTO? in
            guard let user = users[row.userId] else { return nil }
            return GroupMemberDTO(
                userid: row.userId,
                username: user.account,
                nickname: user.nickname,
                avatar: user.avatar,
                joinedAt: row.joinedAt?.timeIntervalSince1970 ?? 0
            )
        }
    }

    // POST /chat/groups/:id/members —— 拉人入群（任何成员都可以，被拉入无需本人同意）
    static func addMember(req: Request) async throws -> GroupSummaryDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        let groupId = try requireGroupId(req)
        let group = try await requireGroup(req, groupId: groupId)
        try await GroupMember.requireMembership(groupId: groupId, userId: myId, on: req.db)

        let payload = try req.content.decode(AddMemberPayload.self)
        let validated = try await validateUserIds([payload.userId], on: req.db)
        guard let inviteeId = validated.first else {
            throw Abort(.badRequest, reason: "缺少要拉入群的用户 userId")
        }

        let already = try await GroupMember.query(on: req.db)
            .filter(\.$groupId == groupId)
            .filter(\.$userId == inviteeId)
            .first()
        guard already == nil else {
            throw Abort(.conflict, reason: "该用户已在群内")
        }

        let count = try await memberCount(on: req.db, groupId: groupId)
        try guardMemberCount(current: count, adding: 1)

        try await GroupMember(groupId: groupId, userId: inviteeId).save(on: req.db)
        return try summary(group: group, memberCount: count + 1)
    }

    // DELETE /chat/groups/:id/members/:userId —— 退群（只能退自己，不能踢人）
    static func leaveGroup(req: Request) async throws -> GroupSummaryDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        let groupId = try requireGroupId(req)
        let group = try await requireGroup(req, groupId: groupId)

        let target = req.parameters.get("userId")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !target.isEmpty else {
            throw Abort(.badRequest, reason: "缺少要移出的用户 ID")
        }
        guard target == myId else {
            throw Abort(.forbidden, reason: "只能退出自己所在的群，不能移出其他成员")
        }

        guard let membership = try await GroupMember.query(on: req.db)
            .filter(\.$groupId == groupId)
            .filter(\.$userId == myId)
            .first()
        else {
            throw Abort(.forbidden, reason: "您不是该群成员，无法退群")
        }

        let count = try await memberCount(on: req.db, groupId: groupId)
        try await membership.delete(on: req.db)
        return try summary(group: group, memberCount: max(count - 1, 0))
    }

    // PATCH /chat/groups/:id —— 改群名/头像，仅创建者
    static func update(req: Request) async throws -> GroupSummaryDTO {
        let user = try req.auth.require(User.self)
        let myId = try user.requireID().uuidString

        let groupId = try requireGroupId(req)
        let group = try await requireGroup(req, groupId: groupId)
        guard group.ownerId == myId else {
            throw Abort(.forbidden, reason: "只有群创建者可以修改群信息")
        }

        let payload = try req.content.decode(UpdateGroupPayload.self)
        var changed = false
        if let name = payload.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw Abort(.badRequest, reason: "群名称不能为空")
            }
            group.name = trimmed
            changed = true
        }
        if let avatar = payload.avatar {
            let trimmed = avatar.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw Abort(.badRequest, reason: "群头像不能为空")
            }
            group.avatar = trimmed
            changed = true
        }
        guard changed else {
            throw Abort(.badRequest, reason: "缺少要修改的群信息（name 或 avatar）")
        }

        try await group.save(on: req.db)
        return try summary(group: group, memberCount: try await memberCount(on: req.db, groupId: groupId))
    }

    // MARK: - 公共校验与查询

    // 成员数上限：建群与拉人共用一处校验，错误文案说明「为什么」
    private static func guardMemberCount(current: Int, adding: Int) throws {
        guard current + adding <= maxMemberCount else {
            throw Abort(.badRequest, reason: "群成员数不能超过 \(maxMemberCount) 人")
        }
    }

    // 校验用户 id 是否存在：格式非法或不存在的都返回明确错误，不静默丢弃；顺带去重
    private static func validateUserIds(_ rawIds: [String], on db: Database) async throws -> [String] {
        var unique: [String] = []
        var seen = Set<String>()
        for raw in rawIds {
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, UUID(uuidString: id) != nil else {
                throw Abort(.badRequest, reason: "用户 ID 格式不正确：\(raw)")
            }
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            unique.append(id)
        }
        guard !unique.isEmpty else { return [] }

        let users = try await User.query(on: db)
            .filter(\.$id ~~ unique.compactMap { UUID(uuidString: $0) })
            .all()
        guard users.count == unique.count else {
            let found = Set(users.compactMap { $0.id?.uuidString })
            let missing = unique.filter { !found.contains($0) }
            throw Abort(.badRequest, reason: "以下用户不存在：\(missing.joined(separator: "、"))")
        }
        return unique
    }

    private static func requireGroupId(_ req: Request) throws -> String {
        guard let raw = req.parameters.get("id"), UUID(uuidString: raw) != nil else {
            throw Abort(.badRequest, reason: "群 ID 格式不正确")
        }
        return raw
    }

    private static func requireGroup(_ req: Request, groupId: String) async throws -> Group {
        guard let uuid = UUID(uuidString: groupId), let group = try await Group.find(uuid, on: req.db) else {
            throw Abort(.notFound, reason: "群不存在")
        }
        return group
    }

    private static func memberCount(on db: Database, groupId: String) async throws -> Int {
        try await GroupMember.query(on: db).filter(\.$groupId == groupId).count()
    }

    private static func usersById(on db: Database, ids: [String]) async throws -> [String: User] {
        let uuids = ids.compactMap { UUID(uuidString: $0) }
        guard !uuids.isEmpty else { return [:] }
        let users = try await User.query(on: db).filter(\.$id ~~ uuids).all()
        return Dictionary(uniqueKeysWithValues: users.compactMap { user in
            user.id.map { ($0.uuidString, user) }
        })
    }

    private static func summary(group: Group, memberCount: Int) throws -> GroupSummaryDTO {
        GroupSummaryDTO(
            id: try group.requireID().uuidString,
            name: group.name,
            avatar: group.avatar,
            ownerId: group.ownerId,
            memberCount: memberCount,
            createdAt: group.createdAt?.timeIntervalSince1970 ?? 0
        )
    }
}
