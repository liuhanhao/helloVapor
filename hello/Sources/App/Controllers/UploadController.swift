//
//  UploadController.swift
//
//  媒体文件上传（issue 03）：multipart 表单上传，按 msgType 校验类型与大小，
//  文件以 UUID + 原扩展名存入独立上传目录（Public/uploads/，由 FileMiddleware 托管），
//  返回可访问的文件 URL。替代原先硬编码单一文件的上传下载接口。
//
//  issue 04：新增 UploadsTypeMiddleware —— /uploads/ 静态访问的 Content-Type 修正，
//  保证浏览器 <audio>/<video> 在聊天窗口内直接播放。
//

import Vapor
import Foundation

// 单个消息类型（msgType）的上传校验规则
struct UploadRule {
    // 允许的文件扩展名（小写）
    let extensions: Set<String>
    // 大小上限（字节）
    let maxBytes: Int
    // 展示名（用于错误提示）
    let label: String

    var maxMB: Int { maxBytes / 1024 / 1024 }
}

// 各消息类型的上传规则：上限与允许格式在此集中配置，便于后续调整
// （规格默认值：图片 jpg/png/gif/webp ≤10MB，音频 mp3/m4a/aac/wav ≤20MB，视频 mp4/mov ≤100MB）
enum UploadRules {
    static let image = UploadRule(
        extensions: ["jpg", "jpeg", "png", "gif", "webp"],
        maxBytes: 10 * 1024 * 1024,
        label: "图片"
    )
    static let audio = UploadRule(
        extensions: ["mp3", "m4a", "aac", "wav"],
        maxBytes: 20 * 1024 * 1024,
        label: "音频"
    )
    static let video = UploadRule(
        extensions: ["mp4", "mov"],
        maxBytes: 100 * 1024 * 1024,
        label: "视频"
    )

    // 请求体收集上限：取各类型上限中最大者（当前为视频 100MB）
    static var largestMaxBytes: Int {
        [image.maxBytes, audio.maxBytes, video.maxBytes].max() ?? 0
    }

    static func rule(for msgType: String) -> UploadRule? {
        switch msgType {
        case "image": return image
        case "audio": return audio
        case "video": return video
        default: return nil
        }
    }
}

// 上传成功返回体
struct UploadResponseDTO: Content {
    // 可访问的文件 URL（相对站点根路径，如 /uploads/<uuid>.jpg）
    var url: String
}

// multipart 请求体：msgType（消息类型）+ file（媒体文件）
struct UploadPayload: Content {
    var msgType: String
    var file: File
}

enum UploadController {

    // 独立上传目录（位于 Public 之下，经 FileMiddleware 以 /uploads/<文件名> 访问）
    static func uploadsDirectory(for req: Request) -> String {
        req.application.directory.workingDirectory + "Public/uploads/"
    }

    // POST /chat/upload —— multipart 表单上传，按 msgType 校验类型与大小，UUID 命名存储
    static func upload(req: Request) async throws -> UploadResponseDTO {
        // 需要登录（token 鉴权）；未携带 token 在解析表单前即返回 401
        let user = try req.auth.require(User.self)

        let payload = try req.content.decode(UploadPayload.self)

        let msgType = payload.msgType.trimmingCharacters(in: .whitespaces).lowercased()
        guard let rule = UploadRules.rule(for: msgType) else {
            throw Abort(.badRequest, reason: "不支持的消息类型 msgType：\(msgType)")
        }

        // 类型校验：按文件扩展名（统一小写比较）
        let ext = (payload.file.filename as NSString).pathExtension.lowercased()
        guard rule.extensions.contains(ext) else {
            throw Abort(.unsupportedMediaType, reason: "\(rule.label)格式不支持，仅支持 \(rule.extensions.sorted().joined(separator: "/"))")
        }

        // 大小校验
        let size = payload.file.data.readableBytes
        guard size > 0 else {
            throw Abort(.badRequest, reason: "上传的文件为空")
        }
        guard size <= rule.maxBytes else {
            throw Abort(.payloadTooLarge, reason: "\(rule.label)大小不能超过 \(rule.maxMB) MB")
        }

        // UUID + 原扩展名命名，存入独立上传目录（目录不存在时自动创建）
        let directory = uploadsDirectory(for: req)
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let storedName = "\(UUID().uuidString.lowercased()).\(ext)"
        let filePath = directory + storedName

        do {
            try await req.fileio.writeFile(payload.file.data, at: filePath)
        } catch {
            throw Abort(.internalServerError, reason: "文件保存失败")
        }

        let url = "/uploads/\(storedName)"

        // 记录归属（A4）：文件已落盘、URL 也已确定，记录失败不影响本次上传结果，
        // 只打印错误——不能因为一条旁路的记录写不进去就让已经成功的文件上传失败
        let record = Upload(
            ownerId: user.id?.uuidString ?? "",
            url: url,
            msgType: msgType,
            storedName: storedName,
            size: size
        )
        do {
            try await record.save(on: req.db)
        } catch {
            print("上传记录写入失败: \(storedName) -> \(error)")
        }

        print("文件已上传: \(storedName)（\(size) 字节）")
        return UploadResponseDTO(url: url)
    }
}

// /uploads/ 静态访问的 Content-Type 修正中间件（issue 04）：
// Vapor 内置的扩展名 MIME 映射对部分上传格式缺失或不当（aac 无映射导致无 Content-Type、
// m4a 被映射为 audio/mpeg），部分浏览器可能因此拒绝在 <audio>/<video> 中直接播放。
// 该中间件注册在 FileMiddleware 之前，拦截对 /uploads/ 的 GET/HEAD 请求，
// 按上传允许的扩展名显式给出正确 Content-Type，流式输出复用 req.fileio（支持 Range，
// 供播放器拖动进度）；文件不存在或扩展名不在集合内时交由后续 FileMiddleware 兜底。
struct UploadsTypeMiddleware: AsyncMiddleware {

    // 上传允许的扩展名 -> 正确的 MIME 类型（与 UploadRules 的规则一一对应）
    static let mimeTypes: [String: String] = [
        "jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
        "gif": "image/gif", "webp": "image/webp",
        "mp3": "audio/mpeg", "m4a": "audio/mp4", "aac": "audio/aac", "wav": "audio/wav",
        "mp4": "video/mp4", "mov": "video/quicktime"
    ]

    static let prefix = "/uploads/"

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // 只拦截对上传目录的文件访问
        guard request.method == .GET || request.method == .HEAD,
              request.url.path.hasPrefix(Self.prefix),
              let name = request.url.path.dropFirst(Self.prefix.count).removingPercentEncoding
        else {
            return try await next.respond(to: request)
        }

        // 仅服务安全文件名（无路径分隔符/上跳/隐藏文件），且扩展名属于上传允许集合
        let ext = name.split(separator: ".").last.map { String($0).lowercased() } ?? ""
        guard !name.isEmpty, !name.contains("/"), !name.contains(".."), !name.hasPrefix("."),
              let mime = Self.mimeTypes[ext]
        else {
            return try await next.respond(to: request)
        }

        let path = UploadController.uploadsDirectory(for: request) + name
        guard FileManager.default.fileExists(atPath: path) else {
            return try await next.respond(to: request)
        }

        let parts = mime.split(separator: "/")
        let mediaType = HTTPMediaType(type: String(parts[0]), subType: String(parts[1]))
        return try await request.fileio.asyncStreamFile(at: path, mediaType: mediaType)
    }
}
