//
//  WebSocket.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/12.
//

import Foundation
import Starscream
import ReactiveSwift

final class ADSWebSocketEventSingle {
    //        let e = WebSocketEventSingle.init()
    //        e.message_signal.observe { event in
    //            switch event {
    //            case let .value(value):
    //                print(value)
    //            case .failed(_):
    //                <#code#>
    //            case .completed:
    //                <#code#>
    //            case .interrupted:
    //                <#code#>
    //            }
    //        }
    //        e.message_signal.observeValues { value in
    //            <#code#>
    //        }
    
    func registeredMessage(handler: @escaping ((String) -> Void)) {
        ADSWebSocketService.sharedInstance.message_signal.observeResult { result in
            switch result {
                case .success(let value):
                    handler(value)
                case .failure(let error):
                    print("信号错误 \(error)")
            }
        }
    }
    
    func registeredEvent(handler: @escaping ((Bool) -> Void)) {
        ADSWebSocketService.sharedInstance.event_signal.observeResult { result in
            switch result {
                case .success(let value):
                    handler(value)
                case .failure(let error):
                    print("信号错误 \(error)")
            }
        }
    }
}

final class ADSWebSocketService: WebSocketDelegate {
    /*
     WebSocket控制帧有3种：Close(关闭帧)、Ping以及Pong。控制帧的操作码定义了0x08(关闭帧)、0x09(Ping帧)、0x0A(Pong帧)。Close关闭帧很容易理解，客户端如果接受到了就关闭连接，客户端也可以发送关闭帧给服务端。Ping和Pong是websocket里的心跳，用来保证客户端是在线的，一般来说只有服务端给客户端发送Ping，然后客户端发送Pong来回应，表明自己仍然在线。

     WebSocket协议深入探究-https://www.sohu.com/a/227600866_472869
     OPCODE：4位 ， 解释PayloadData，如果接收到未知的opcode，接收端必须关闭连接。
     0x0表示附加数据帧
     0x1表示文本数据帧
     0x2表示二进制数据帧
     0x3-7暂时无定义，为以后的非控制帧保留
     0x8表示连接关闭
     0x9表示ping
     0xA表示pong
     0xB-F暂时无定义，为以后的控制帧保留
     */
    
    fileprivate let (message_signal, message_observer) = Signal<String, Error>.pipe()
    fileprivate let (binary_signal, binary_observer) = Signal<Data, Error>.pipe()
    fileprivate let (event_signal, event_observer) = Signal<Bool, Error>.pipe()
    
    private var isConnected:Bool = false
    private var socket = WebSocket.init(request: URLRequest.init(url: URL.init(string: ADSChatURL.ipAddress + "chat/")!))
    
    // 单例
    static let sharedInstance = ADSWebSocketService()
    
    private init() {
        socket.delegate = self
    }
    
    func connect() {
        guard self.isConnected else {
            self.socket.connect()
            return
        }
    }
    
    func disconnect() {
        guard self.isConnected == false else {
            self.socket.disconnect()
            return
        }
    }
    
    /// WebSocket 事件回调
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        print("didReceive:::")
        
        switch event {
            case .connected(let headers):
                isConnected = true
                print("websocket is connected: \(headers)")
                event_observer.send(value: isConnected)
            case .disconnected(let reason, let code):
                isConnected = false
                print("websocket is disconnected: \(reason) with code: \(code)")
                event_observer.send(value: isConnected)
            case .text(let string):
                print("Received text: \(string)")
                message_observer.send(value: string)
            case .binary(let data):
                print("Received data: \(data.count)")
                binary_observer.send(value: data)
            
            
            case .ping(_):
                var buffer:[UInt8] = [UInt8]()
                buffer.insert(0x01, at: 0)
                buffer.insert(0x01, at: 1)
                let data = ADSHexadecimal.bytesArrayConversionData(bytesArray: buffer)
                socket.write(pong: data)
                break
            case .pong(_):
                break
            case .viabilityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            case .cancelled:
                isConnected = false
            case .error(let error):
                isConnected = false
                handleError(error)
        }
    }
    
    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket encountered an error")
        }
    }
    
    
}
