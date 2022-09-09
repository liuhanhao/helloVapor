import Vapor
import FluentKit
import Foundation
import SwiftyJSON

public var application:Application? = nil

func routes(_ app: Application) throws {
    
    application = app
    
    ///所有常见的 HTTP 方法都可以作为 Application 的方法使用。它们接受一个或多个字符串参数，这些字符串参数表示请求路径，以 / 分隔。
    // 注册用户
    app.post("chat", "registered") { req async throws -> User in
        
        let create = try req.content.decode(User.Create.self)
        guard create.password == create.confirmPassword else {
            throw Abort(.badRequest, reason: "Passwords did not match")
        }
        let user = try User(
            avatar: create.avatar,
            nickname: create.nickname,
            account: create.account,
            passwordHash: Bcrypt.hash(create.password)
        )
        try await user.save(on: req.db)
        return user
    }
    
    // 登录
    // 该请求通过 Basic Auth 认证头传递用户名Username: test@volor.codes 和密码Password: ici42。你应该会看到返回了之前创建的用户。
    // 虽然理论上可以使用基本身份验证来保护所有端点，但建议使用单独的令牌。这可以最大限度地减少你必须通过 Internet 发送用户敏感密码的频率。它还使身份验证速度更快，因为在登录期间只需要执行密码散列。
    let passwordProtected = app.grouped(User.authenticator())
    passwordProtected.post("chat", "login") { req async throws -> UserToken in
        let user = try req.auth.require(User.self)
        // 这里的逻辑后面再补
        if (user.account == "123@qq.com") {
            print("密码验证通过")
        }
        
        let token = try user.generateToken()
        try await token.save(on: req.db)
        return token
    }
    
    // 路由验证保护
    let tokenProtected = app.grouped(UserToken.authenticator())
    tokenProtected.get("chat", "me") { req -> User in
        try req.auth.require(User.self)
    }

    // 当请 request body 被流处理时，req.body.data 会是 nil， 你必须使用 req.body.drain 来处理每个被发送到你的路由数据块。
    // Request body will not be collected into a buffer.
    // 上传文件接口
    app.on(.POST, "chat", "uploadFile", body: .stream) { request async -> String in
        // 创造一个预先成功的 future。
        let resultsPromise: EventLoopPromise<String> = request.eventLoop.makePromise(of: String.self)
        // 创造一个预先失败的 future。
//        let futureString: EventLoopFuture<String> = eventLoop.makeFailedFuture(error)

        var fileData = ByteBuffer.init()
        // 这个方法是同步的
        request.body.drain { bodyStream in
            switch bodyStream {
            case .buffer(let buffer): // 分多次读取body流在这个分支返回
                var currentBuffer = ByteBuffer.init(buffer: buffer)
                fileData.writeBuffer(&currentBuffer) // 叠加流
                return request.eventLoop.makeSucceededVoidFuture()
            case .end: // 流读取完成  将缓冲区数据写入文件
                resultsPromise.succeed("success")
                return request.fileio.writeFile(fileData, at: "/Users/taylor/Desktop/helloVapor/uploadFile/666.jpg")
            case .error(let error):
                resultsPromise.fail(error)
                return request.eventLoop.makeFailedFuture(error)
            }
        }
        
        // 创建一个信号等待
        let resultsFuture: EventLoopFuture<String> = resultsPromise.futureResult
        let results = try! resultsFuture.wait()
        
        return results
        
    }
    
    app.on(.POST, "chat", "downloadFile") { request -> Response in
//        // 异步流文件作为HTTP响应。
//        request.fileio.streamFile(at: "/path/to/file").map { res in
//            print(res) // 响应
//        }

        // 同步
        // streamFile 方法将文件流转换为 Response。 此方法将自动设置适当的响应头，例如 ETag 和 Content-Type。
        let result = request.fileio.streamFile(at: "/Users/taylor/Desktop/helloVapor/uploadFile/666.jpg")
        print(result)

        return result
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



