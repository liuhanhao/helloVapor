////
////  WebSocketService.swift
////  
////
////  Created by admin on 2022/9/2.
////
//
//import Vapor
//
//let drop = Droplet()
//
//drop.socket("ws") { req, ws in
//    print("New WebSocket connected: \(ws)")
//
//    // ping the socket to keep it open
//    try background {
//        while ws.state == .open {
//            try? ws.ping()
//            drop.console.wait(seconds: 10) // every 10 seconds
//        }
//    }
//
//    ws.onText = { ws, text in
//        print("Text received: \(text)")
//
//        // reverse the characters and send back
//        let rev = String(text.characters.reversed())
//        try ws.send(rev)
//    }
//
//    ws.onClose = { ws, code, reason, clean in
//        print("Closed.")
//    }
//}
//
//drop.run()
