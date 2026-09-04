//
//  UserProfileController.swift
//
//  个人资料修改（B3 01）：改自己的昵称与头像。
//
//  只从鉴权结果取身份——没有「改别人」的入参，不为将来的管理员功能预留后门。
//

import Vapor
import Fluent

// PATCH /chat/me 的请求体：昵称与头像至少给一个，都给则都改
struct UpdateMePayload: Content {
    var nickname: String?
    var avatar: String?
}

enum UserProfileController {

    // PATCH /chat/me —— 改自己的昵称与头像，返回更新后的公开身份
    static func updateMe(req: Request) async throws -> User.Public {
        let user = try req.auth.require(User.self)
        let payload = try req.content.decode(UpdateMePayload.self)

        // 与建群时的群名校验一致：trim 后再判空
        let nickname = payload.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let avatar = payload.avatar?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !nickname.isEmpty || !avatar.isEmpty else {
            throw Abort(.badRequest, reason: "昵称与头像至少提供一项")
        }

        if !nickname.isEmpty {
            user.nickname = nickname
        }
        if !avatar.isEmpty {
            // 头像必须是站内相对路径：挡掉 http:// 外链与 javascript: / data: 这类危险来源。
            // 外界可控字符串最终会进 <img src>，这里就收口
            guard avatar.hasPrefix("/") else {
                throw Abort(.badRequest, reason: "头像必须是站内路径（以 / 开头）")
            }
            user.avatar = avatar
        }

        try await user.save(on: req.db)
        return user.toPublic()
    }
}
