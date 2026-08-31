//
//  UserQueryController.swift
//
//  用户查询（issue 05）：按账号或用户 ID（userid）查询用户，
//  用于发起与尚无任何聊天记录的联系人的新会话。
//  仅返回公开身份信息（User.Public），不含密码散列等敏感字段。
//

import Vapor
import Fluent

enum UserQueryController {

    // 单次查询返回的最大条数（按账号查询最多命中一条，按用户 ID 亦为一条）
    static let maxResults = 20

    // GET /chat/users?q=<账号或用户 ID>
    // —— 返回匹配用户的公开身份信息；无匹配时返回空数组（由前端给出明确提示）
    static func search(req: Request) async throws -> [User.Public] {
        // 需要登录（token 鉴权）：避免未登录者枚举站内用户
        _ = try req.auth.require(User.self)

        struct UserQuery: Content {
            var q: String?
        }
        let query = try req.query.decode(UserQuery.self)
        let keyword = (query.q ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            throw Abort(.badRequest, reason: "缺少查询关键字 q")
        }

        let builder = User.query(on: req.db)
        if let userID = UUID(uuidString: keyword) {
            // 形如 UUID 的关键字：同时按用户 ID 与账号匹配（账号也可能恰为 UUID 形式）
            builder.group(.or) { group in
                group.filter(\.$id == userID)
                group.filter(\.$account == keyword)
            }
        } else {
            builder.filter(\.$account == keyword)
        }

        let users = try await builder.limit(maxResults).all()
        return users.map { $0.toPublic() }
    }
}
