//
//  WebSocketService.swift
//
//
//  Created by admin on 2022/9/2.
//

import Vapor
import Foundation
import SwiftyJSON

fileprivate var _webSockets:[String : WebSocket] = [:]

// User表格
final class SocketConnectUser: Content {

    var username: String
    var userid: String

    init(userid: String, username: String) {
        self.username = username
        self.userid = userid
    }
}


final class WebSocketService {
    // 解析socket消息体
    static func parsingWebSocketMessage(message text:String, webSocket:WebSocket) {
        
        if let jsonString = text.data(using: .utf8, allowLossyConversion: false) {
            
            do {
                let jsonObj = try JSON(data: jsonString)
                
                let type = jsonObj["type"].stringValue // ”chatMessage” 聊天消息
                let mine = Mine.init(avatar: jsonObj["data"]["mine"]["avatar"].stringValue,
                                     content: jsonObj["data"]["mine"]["content"].stringValue,
                                     mine: jsonObj["data"]["mine"]["mine"].boolValue,
                                     userId: jsonObj["data"]["mine"]["userid"].stringValue,
                                     username: jsonObj["data"]["mine"]["username"].stringValue,
                                     nickname: jsonObj["data"]["mine"]["nickname"].stringValue)
                let to = To.init(avatar: jsonObj["data"]["to"]["avatar"].stringValue,
                                 userId: jsonObj["data"]["to"]["userid"].stringValue,
                                 username: jsonObj["data"]["to"]["username"].stringValue,
                                 nickname: jsonObj["data"]["to"]["nickname"].stringValue)
                
                let chatMessage = ChatMessage.init(type: type, mine: mine, to: to)
                let _ = chatMessage.save(on: application!.db)
            } catch {
                print("json 解析错误")
            }
            
        }
        
    }

    static func socketRoutesEvent(req: Request, websocket: WebSocket) {
        
        let connectUser:SocketConnectUser? = try? req.query.decode(SocketConnectUser.self)
        if (connectUser != nil) {
            // 添加webSocket
            _webSockets[connectUser!.userid] = websocket
            
        //        // ping the socket to keep it open
        //        try background {
        //            while ws.state == .open {
        //                try? ws.ping()
        //                drop.console.wait(seconds: 10) // every 10 seconds
        //            }
        //        }

            websocket.onText({ ws, text in
                print("Text received: \(text)")

        //            let json = app.getDictionaryFromJSONString(text)
                
                // reverse the characters and send back
                let rev = String(text.reversed())
                ws.send(rev)
                
                parsingWebSocketMessage(message: text, webSocket: ws)
                
        //            let resultsPromise: EventLoopPromise<Void> = request.eventLoop.makePromise(of: String.self)
        //
        //            ws.send(rev, promise: resultsPromise)
        //            let eventLoop = EventLoop.init()
        //
        //            let promise = EventLoopPromise.()
        //            ws.send(..., promise: promise)
        //            promise.futureResult.whenComplete { result in
        //                // 发送成功或失败。
        //            }

            })
            websocket.onClose.whenComplete { result in
                // 关闭成功或失败。
                print("Closed.")
        //            _webSocketArray.removeAll { webSocket in
        //                webSocket == ws
        //            }
            }
        }
    }
}


