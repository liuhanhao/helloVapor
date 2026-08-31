//
//  Upload.swift
//
//  上传文件记录（A4：媒体文件的归属）
//
//  在此之前，文件写进 Public/uploads/ 就再无下文：既不知道是谁传的，也无法回答
//  「这个文件还能不能删」「某个用户占了多少空间」。本表把归属记下来，为后续的
//  清理与配额打底。
//
//  注意：本表只解决「归属」，不解决「访问控制」——媒体 URL 目前仍是公开直链，
//  任何拿到 URL 的人都能拉取。收紧访问的方案与代价记录在
//  .scratch/auth-and-security/issues/02 中。
//

import Fluent
import Vapor

final class Upload: Model, Content {
    static let schema = "uploads"

    @ID(key: .id)
    var id: UUID?

    // 上传者的 userid
    @Field(key: "owner_id")
    var ownerId: String

    // 可访问的文件 URL（相对站点根路径，如 /uploads/<uuid>.jpg）
    @Field(key: "url")
    var url: String

    // 上传时的 msgType（image / audio / video）
    @Field(key: "msg_type")
    var msgType: String

    // 落盘的文件名（UUID + 原扩展名）
    @Field(key: "stored_name")
    var storedName: String

    // 文件字节数
    @Field(key: "size")
    var size: Int

    @Timestamp(key: "created_at", on: .create, format: .unix)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, ownerId: String, url: String, msgType: String, storedName: String, size: Int) {
        self.id = id
        self.ownerId = ownerId
        self.url = url
        self.msgType = msgType
        self.storedName = storedName
        self.size = size
    }
}

extension Upload {
    struct Migration: AsyncMigration {
        var name: String { "CreateUpload" }

        func prepare(on database: Database) async throws {
            try await database.schema("uploads")
                .id()
                .field("owner_id", .string, .required)
                .field("url", .string, .required)
                .field("msg_type", .string, .required)
                .field("stored_name", .string, .required)
                .field("size", .int, .required)
                .field("created_at", .double)
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema("uploads").delete()
        }
    }
}
