import Vapor
import FluentKit
import Foundation
import SwiftyJSON

public var application:Application? = nil

func routes(_ app: Application) throws {
    
    application = app
    
    ///所有常见的 HTTP 方法都可以作为 Application 的方法使用。它们接受一个或多个字符串参数，这些字符串参数表示请求路径，以 / 分隔。
    // 注册用户
    app.post("chat", "registered") { req async throws -> User.Public in
        
        let create = try req.content.decode(User.Create.self)
        guard create.password == create.confirmPassword else {
            throw Abort(.badRequest, reason: "两次输入的密码不一致")
        }
        // 账号唯一性校验，避免直接报唯一约束错误
        let existing = try await User.query(on: req.db).filter(\.$account == create.account).first()
        guard existing == nil else {
            throw Abort(.conflict, reason: "账号已存在")
        }
        let user = try User(
            avatar: create.avatar,
            nickname: create.nickname,
            account: create.account,
            passwordHash: Bcrypt.hash(create.password)
        )
        try await user.save(on: req.db)
        return user.toPublic()
    }
    
    // 登录
    // 该请求通过 Basic Auth 认证头传递用户名Username: test@volor.codes 和密码Password: ici42。你应该会看到返回了之前创建的用户。
    // 虽然理论上可以使用基本身份验证来保护所有端点，但建议使用单独的令牌。这可以最大限度地减少你必须通过 Internet 发送用户敏感密码的频率。它还使身份验证速度更快，因为在登录期间只需要密码散列。
    let passwordProtected = app.grouped(User.authenticator())
    passwordProtected.post("chat", "login") { req async throws -> UserToken in
        let user = try req.auth.require(User.self)
        
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    // 路由验证保护：返回当前登录用户信息（不含密码散列）
    let tokenProtected = app.grouped(UserToken.authenticator())
    tokenProtected.get("chat", "me") { req -> User.Public in
        try req.auth.require(User.self).toPublic()
    }

    // 会话列表：按联系人分组返回对方身份与最后一条消息，按最后消息时间倒序
    tokenProtected.get("chat", "sessions") { req async throws -> [SessionSummaryDTO] in
        try await ChatHistoryController.sessions(req: req)
    }

    // 历史消息：与指定联系人的双方消息按时间正序分页返回
    tokenProtected.get("chat", "history") { req async throws -> HistoryResponseDTO in
        try await ChatHistoryController.history(req: req)
    }

    // 媒体文件上传（issue 03）：标准 multipart 表单（msgType + file），
    // 按 msgType 校验类型与大小，UUID 命名存入 Public/uploads/，返回文件 URL。
    // 替代原先硬编码单一文件（uploadFile/666.jpg）的上传下载接口。
    // body 收集上限取各类型上限中最大者（视频 100MB），超限请求直接被拒；
    // 各类型的具体上限在 UploadRules 中集中配置。
    tokenProtected.on(.POST, "chat", "upload", body: .collect(maxSize: ByteCount(value: UploadRules.largestMaxBytes))) { req async throws -> UploadResponseDTO in
        try await UploadController.upload(req: req)
    }
    
    app.webSocket("chat", "webSocket") { request, ws in
        // Connected WebSocket.
        WebSocketService.socketRoutesEvent(req: request, websocket: ws)
    }
    
//    ///路径动态化。注意，名称 “vapor” 在路径和响应中都是硬编码的。让我们对它进行动态化，以便你可以访问 /hello/<any name> 并获得响应。
//    /*
//     常量 (foo)
//     参数路径 (:foo)
//     任何路径 (*)
//     通配路径 (**)
//     */
//    app.get("hello", ":name") { req async -> String in
////        let name: String? = req.parameters.get("name")
//        let hello:Hello? = try? req.query.decode(Hello.self)
//        let name: String? = req.query["name"]
//
//        print(name)
//
//        return "hello " + (hello?.name ?? "")
//    }
//
//    // Collects streaming bodies (up to 1mb in size) before calling this route.
//    app.on(.POST, "listings", body: .collect(maxSize: "1mb")) { req -> String in
//        // Handle request.
//
//        let chatMessages:[ChatMessage] = try await ChatMessage.query(on: req.db).all()
//        print("111" + (chatMessages.first?.name ?? ""))
//        let hello:Hello? = try req.content.decode(Hello.self)
//        print(hello?.name)
//
////        let hello = try req.query.decode(Hello.self, using: decoder as! URLQueryDecoder)
////        return "Hello, \(object.name ?? "Anonymous")"
//
//        let chatMessage = ChatMessage.init(id: nil, name: hello!.name!)
//        try await chatMessage.save(on: req.db)
//
//        return "version"
//    }
    

    
// .secondsSince1970
//    drop.post("upMoreImage"){ request in
//      for i in 1...9{
//        //根据字段名获取图片信息
//        let img = request.formData?["img\(i)"];
//        let imgPart = img?.part;
//        let imgBody = imgPart?.body;
//        if let imgDat = imgBody{
//            //将bytes数据转为Data类型数据
//            let data = NSData.init(bytes: imgDat, length: (imgBody?.count)!);
//            //存到电脑桌面
//            try?data.write(to: URL.init(fileURLWithPath: "/Users/xiaocangkeji/Desktop/img\(i).jpg"), options: NSData.WritingOptions.atomic);
//        }
//      }
//       return try JSON(node:["message":"success"]);
//    }
    
    
}



