//
//  WebSocketService.swift
//
//
//  Created by admin on 2022/9/2.
//

import Vapor
import Foundation
import SwiftyJSON

// 连接通过查询参数携带的身份（本次不接入 token 鉴权）
final class SocketConnectUser: Content {

    var username: String
    var userid: String

    init(userid: String, username: String) {
        self.username = username
        self.userid = userid
    }
}


final class WebSocketService {

    // 进程内连接表：userid -> WebSocket（单实例部署假设）
    // 连接可能来自不同 event loop，读写需加锁
    private static let connectionsLock = NSLock()
    private static var webSockets: [String: WebSocket] = [:]

    static func socketRoutesEvent(req: Request, websocket: WebSocket) {

        guard let connectUser = try? req.query.decode(SocketConnectUser.self) else {
            // 缺少身份信息，拒绝连接
            _ = websocket.close(code: .goingAway)
            return
        }

        // 注册连接；同一用户重复连接时关闭旧连接
        connectionsLock.lock()
        if let old = webSockets[connectUser.userid], !old.isClosed {
            _ = old.close()
        }
        webSockets[connectUser.userid] = websocket
        connectionsLock.unlock()
        print("WebSocket 已连接: \(connectUser.userid)")

        websocket.onText({ _, text in
            handleMessage(text: text, sender: websocket)
        })
        websocket.onClose.whenComplete { _ in
            print("WebSocket 已关闭: \(connectUser.userid)")
            connectionsLock.lock()
            // 仅当连接表里仍是本连接时才移除，避免误删后注册的连接
            if webSockets[connectUser.userid] === websocket {
                webSockets.removeValue(forKey: connectUser.userid)
            }
            connectionsLock.unlock()
        }
    }

    // 解析并路由一条消息：入库 → 推送在线接收方 → 回送发送方确认
    private static func handleMessage(text: String, sender: WebSocket) {

        guard let jsonData = text.data(using: .utf8, allowLossyConversion: false),
              let jsonObj = try? JSON(data: jsonData) else {
            print("json 解析错误")
            return
        }

        let type = jsonObj["type"].stringValue // ”chatMessage” 聊天消息

        // 未携带 msgType 的消息按 text 处理（兼容 iOS 端旧格式消息）
        let rawMsgType = jsonObj["data"]["mine"]["msgType"].stringValue
        let msgType = rawMsgType.isEmpty ? "text" : rawMsgType

        let mine = Mine.init(avatar: jsonObj["data"]["mine"]["avatar"].stringValue,
                             content: jsonObj["data"]["mine"]["content"].stringValue,
                             mine: jsonObj["data"]["mine"]["mine"].boolValue,
                             userId: jsonObj["data"]["mine"]["userid"].stringValue,
                             username: jsonObj["data"]["mine"]["username"].stringValue,
                             nickname: jsonObj["data"]["mine"]["nickname"].stringValue,
                             msgType: msgType)
        let to = To.init(avatar: jsonObj["data"]["to"]["avatar"].stringValue,
                         userId: jsonObj["data"]["to"]["userid"].stringValue,
                         username: jsonObj["data"]["to"]["username"].stringValue,
                         nickname: jsonObj["data"]["to"]["nickname"].stringValue)

        let chatMessage = ChatMessage.init(type: type, mine: mine, to: to)
        guard let db = application?.db else {
            print("application 未初始化，消息丢弃")
            return
        }

        Task {
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

            // 接收方在线则推送消息（原文附加消息 id 与服务端时间戳）；离线则不推送、不报错，消息仅入库
            connectionsLock.lock()
            let receiverSocket = webSockets[to.userId]
            connectionsLock.unlock()
            if let receiverSocket = receiverSocket, !receiverSocket.isClosed {
                var forwarded = jsonObj
                if let messageId = messageId {
                    forwarded["data"]["id"] = JSON(messageId)
                }
                forwarded["data"]["timestamp"] = JSON(serverTimestamp)
                if let forwardedString = forwarded.rawString() {
                    try? await receiverSocket.send(forwardedString)
                }
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
            if let ackString = ack.rawString() {
                try? await sender.send(ackString)
            }
        }
    }
}
