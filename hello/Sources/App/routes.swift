import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "It works!"
    }
    
    app.webSocket("chat") { req, ws in
        // Connected WebSocket.
        print("777777")
        print(ws)
        print("New WebSocket connected: \(ws)")

//        // ping the socket to keep it open
//        try background {
//            while ws.state == .open {
//                try? ws.ping()
//                drop.console.wait(seconds: 10) // every 10 seconds
//            }
//        }

        ws.onText({ ws, text in
            print("Text received: \(text)")

            // reverse the characters and send back
            let rev = String(text.reversed())
            ws.send(rev)
//            ws.send(rev, promise: EventLoopPromise<Void>?)
//            let eventLoop = EventLoop.init()
//
//            let promise = EventLoopPromise.()
//            ws.send(..., promise: promise)
//            promise.futureResult.whenComplete { result in
//                // 发送成功或失败。
//            }

        })
        ws.onClose.whenComplete { result in
            // 关闭成功或失败。
            print("Closed.")
        }

        
    }
    
    ///所有常见的 HTTP 方法都可以作为 Application 的方法使用。它们接受一个或多个字符串参数，这些字符串参数表示请求路径，以 / 分隔。
    app.get("hello", "vapor") { req async -> String in
        "Hello, world!"
    }
    
    ///路径动态化。注意，名称 “vapor” 在路径和响应中都是硬编码的。让我们对它进行动态化，以便你可以访问 /hello/<any name> 并获得响应。
    /*
     常量 (foo)
     参数路径 (:foo)
     任何路径 (*)
     通配路径 (**)
     */
    app.get("hello", ":name") { req async -> String in
//        let name: String? = req.parameters.get("name")
        let hello:Hello? = try? req.query.decode(Hello.self)
        let name: String? = req.query["name"]
        
        print(name)
        
        return "hello " + (hello?.name ?? "")
    }
    
    // Collects streaming bodies (up to 1mb in size) before calling this route.
    app.on(.POST, "listings", body: .collect(maxSize: "1mb")) { req -> String in
        // Handle request.

        let hello:Hello? = try req.content.decode(Hello.self)
        print(hello?.name)

//        let hello = try req.query.decode(Hello.self, using: decoder as! URLQueryDecoder)
//        return "Hello, \(object.name ?? "Anonymous")"
        return "version"
    }
    
    
    
    // Request body will not be collected into a buffer.
    app.on(.POST, "upload", body: .stream) { req in
        return "hello";
    }

}
