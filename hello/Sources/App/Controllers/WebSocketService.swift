//
//  WebSocketService.swift
//
//
//  Created by admin on 2022/9/2.
//

import Vapor
import Fluent
import Foundation
import SwiftyJSON

// 连接身份：由服务端凭 token 解析得出（issue 06）
// 不再由客户端通过查询参数自报——否则任何人在知道他人 userid 后即可冒充其身份收发消息
final class SocketConnectUser {

    var username: String  // 账号
    var userid: String
    var nickname: String
    var avatar: String

    init(user: User) {
        self.userid = user.id?.uuidString ?? ""
        self.username = user.account
        self.nickname = user.nickname
        self.avatar = user.avatar
    }
}


// 连接表：userid -> WebSocket（单实例部署假设）
// 所有读写都经同一把 pthread 互斥锁串行化（锁操作不跨 await，可安全用于 async 上下文）；
// 另起类型是为了把「连接存在哪」收敛到一个 seam 上——将来要多实例，替换本类型的实现即可，调用方不动
private final class ConnectionTable: @unchecked Sendable {
    private var mutex = pthread_mutex_t()
    private var sockets: [String: WebSocket] = [:]

    init() {
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    /// 注册连接，返回被顶替下来的旧连接（无则 nil）
    func register(userid: String, socket: WebSocket) -> WebSocket? {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        let old = sockets[userid]
        sockets[userid] = socket
        return old
    }

    func socket(for userid: String) -> WebSocket? {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return sockets[userid]
    }

    /// 仅当表里仍是该连接时才移除，避免误删后注册的连接
    func remove(userid: String, socket: WebSocket) {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        if sockets[userid] === socket {
            sockets.removeValue(forKey: userid)
        }
    }
}

final class WebSocketService {

    // 进程内连接表（连接可能来自不同 event loop，读写必须串行化）
    private static let connections = ConnectionTable()

    static func socketRoutesEvent(req: Request, websocket: WebSocket) {

        // 握手阶段只取一次 token（Request 不跨 Task 使用）。
        // 优先查询参数：浏览器 WebSocket API 无法自定义请求头；同时兼容 Authorization: Bearer
        let tokenValue: String? = req.query[String.self, at: "token"] ?? req.headers.bearerAuthorization?.token

        // 拒绝连接（1008 = policy violation）
        func reject(_ reason: String) {
            print("WebSocket 连接被拒：\(reason)")
            _ = websocket.close(code: .policyViolation)
        }

        guard let tokenValue, !tokenValue.isEmpty, let db = application?.db else {
            reject("缺少 token")
            return
        }

        // 鉴权全程走 EventLoopFuture，不切到 Task：WebSocket 绑定在连接的 event loop 上，
        // 在其它线程上注册回调或关闭连接会触发 NIO 的 NIOLoopBound 断言
        UserToken.query(on: db)
            .filter(\UserToken.$value == tokenValue)
            .first()
            .flatMap { (token: UserToken?) -> EventLoopFuture<User?> in
                guard let token = token else { return req.eventLoop.makeSucceededFuture(nil) }
                return token.$user.get(on: db).map { user -> User? in user }
            }
            .whenComplete { result in
                switch result {
                case .failure(let error):
                    print("WebSocket 鉴权查询失败: \(error)")
                    reject("鉴权失败")
                case .success(let user):
                    guard let user = user else {
                        reject("token 无效")
                        return
                    }
                    register(user: user, websocket: websocket)
                }
            }
    }

    // 注册一条已鉴权的连接；同一用户重复连接时关闭旧连接
    private static func register(user: User, websocket: WebSocket) {
        let connectUser = SocketConnectUser(user: user)

        let oldSocket = connections.register(userid: connectUser.userid, socket: websocket)
        if let oldSocket = oldSocket, !oldSocket.isClosed {
            _ = oldSocket.close()
        }
        print("WebSocket 已连接: \(connectUser.userid)")

        // 注册之后才开始接收消息：鉴权期间到达的消息一律丢弃（未鉴权连接不接受任何消息）
        websocket.onText({ _, text in
            handleMessage(text: text, sender: websocket, senderUser: connectUser)
        })
        websocket.onClose.whenComplete { _ in
            print("WebSocket 已关闭: \(connectUser.userid)")
            connections.remove(userid: connectUser.userid, socket: websocket)
        }
    }

    // 解析并路由一条消息：校验收件主体 → 入库 → 扇出给在线接收方 → 回送发送方确认
    // senderUser 为连接绑定的身份：发送者一律以它为准，客户端上报的身份字段全部忽略
    private static func handleMessage(text: String, sender: WebSocket, senderUser: SocketConnectUser) {

        guard let jsonData = text.data(using: .utf8, allowLossyConversion: false),
              let jsonObj = try? JSON(data: jsonData) else {
            print("json 解析错误")
            return
        }

        let type = jsonObj["type"].stringValue // ”chatMessage” 聊天消息

        // 未携带 msgType 的消息按 text 处理（兼容 iOS 端旧格式消息）
        let rawMsgType = jsonObj["data"]["mine"]["msgType"].stringValue
        let msgType = rawMsgType.isEmpty ? "text" : rawMsgType

        // 发送者身份取连接绑定的用户（含头像），防止伪造发件人；内容字段仍由客户端提供
        let mine = Mine.init(avatar: senderUser.avatar,
                             content: jsonObj["data"]["mine"]["content"].stringValue,
                             mine: jsonObj["data"]["mine"]["mine"].boolValue,
                             userId: senderUser.userid,
                             username: senderUser.username,
                             nickname: senderUser.nickname,
                             msgType: msgType)
        let to = To.init(avatar: jsonObj["data"]["to"]["avatar"].stringValue,
                         userId: jsonObj["data"]["to"]["userid"].stringValue,
                         username: jsonObj["data"]["to"]["username"].stringValue,
                         nickname: jsonObj["data"]["to"]["nickname"].stringValue)

        // 收件主体：data.to.type 缺省按 user 处理（iOS 旧格式消息不带该字段）；
        // 群聊时 to.userid 位置填群 id（ADR-0002：扩展现有协议而非重新设计）
        let toType = RecipientType(rawValue: jsonObj["data"]["to"]["type"].stringValue) ?? .user

        let chatMessage = ChatMessage.init(type: type, mine: mine, to: to,
                                          toType: toType.rawValue, toId: to.userId)
        guard let db = application?.db else {
            print("application 未初始化，消息丢弃")
            return
        }

        Task {
            // 群消息：一次查询同时解决「群是否存在 + 发送者是否成员 + 扇出名单」
            // （群不存在与不是成员在这里等价：都查不到任何成员记录）
            var groupMemberIds: [String] = []
            if toType == .group {
                do {
                    groupMemberIds = try await GroupMember.query(on: db)
                        .filter(\.$groupId == chatMessage.toId)
                        .all()
                        .map { $0.userId }
                } catch {
                    print("群成员查询失败: \(error)")
                    await send(json: ["type": "chatMessageError",
                                      "data": ["reason": "群成员校验失败，消息未发送"]], to: sender)
                    return
                }
                guard groupMemberIds.contains(senderUser.userid) else {
                    await send(json: ["type": "chatMessageError",
                                      "data": ["reason": "群不存在或您不是该群成员，消息未发送"]], to: sender)
                    return
                }
            }

            // 消息入库
            do {
                try await chatMessage.save(on: db)
            } catch {
                print("消息入库失败: \(error)")
            }

            // 入库后生成的消息 id 与服务端时间戳，随推送与确认一并下发，
            // 供客户端把实时消息与历史查询结果对齐去重
            let messageId = chatMessage.id?.uuidString
            let serverTimestamp = chatMessage.createdAt?.timeIntervalSince1970 ?? Date().timeIntervalSince1970

            // 扇出：单聊给接收方一份；群聊给每个在线成员各一份。
            // 发送者自己不回推（自己的消息由本地乐观渲染 + ack 确认）
            let recipients = toType == .group
                ? groupMemberIds.filter { $0 != senderUser.userid }
                : [chatMessage.toId]
            for recipientId in recipients {
                guard let receiverSocket = connections.socket(for: recipientId),
                      !receiverSocket.isClosed else { continue }
                var forwarded = jsonObj
                // 推送前用连接绑定的身份覆盖发送者字段：客户端原文里的身份不可信，
                // 否则连接者可在 payload 里冒用他人身份，接收方看到的发件人是假的。
                // 群聊气泡靠这里的 nickname 显示发送者，必须是服务端的真实值
                forwarded["data"]["mine"]["userid"] = JSON(senderUser.userid)
                forwarded["data"]["mine"]["username"] = JSON(senderUser.username)
                forwarded["data"]["mine"]["nickname"] = JSON(senderUser.nickname)
                forwarded["data"]["mine"]["avatar"] = JSON(senderUser.avatar)
                // 收件主体以服务端判定为准：客户端原文里的 to 不参与路由
                forwarded["data"]["to"]["type"] = JSON(toType.rawValue)
                forwarded["data"]["to"]["userid"] = JSON(chatMessage.toId)
                if let messageId = messageId {
                    forwarded["data"]["id"] = JSON(messageId)
                }
                forwarded["data"]["timestamp"] = JSON(serverTimestamp)
                await send(json: forwarded, to: receiverSocket)
            }

            // 回送发送方一份确认（含消息 id 与服务端时间戳），替代现有“反转回显”的占位逻辑
            var ack: JSON = [
                "type": "chatMessageAck",
                "data": [
                    "timestamp": serverTimestamp,
                    "content": mine.content
                ]
            ]
            if let messageId = messageId {
                ack["data"]["id"] = JSON(messageId)
            }
            await send(json: ack, to: sender)
        }
    }

    /// 给一组在线用户各推一份（离线用户静默跳过：与消息扇出一致，不做离线补偿）。
    /// 抽出这个 seam 是为了让「谁在线、怎么推」只有一处说了算——撤回是第一个
    /// 「不发消息也要推帧」的场景
    static func broadcast(_ json: JSON, to userIds: [String]) async {
        for userId in userIds {
            guard let socket = connections.socket(for: userId), !socket.isClosed else { continue }
            await send(json: json, to: socket)
        }
    }

    // 统一的发送出口（发送失败不中断后续推送：对端可能刚好断开）
    private static func send(json: JSON, to socket: WebSocket) async {
        guard let text = json.rawString() else { return }
        try? await socket.send(text)
    }
}
