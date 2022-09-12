//
//  WebSocket.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/12.
//

import Foundation
import Starscream
import ReactiveSwift

final class WebSocketEventSingle {
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
        WebSocketService.sharedInstance.message_signal.observeResult { result in
            switch result {
                case .success(let value):
                    handler(value)
                case .failure(let error):
                    print("信号错误 \(error)")
            }
        }
    }
    
    func registeredEvent(handler: @escaping ((Bool) -> Void)) {
        WebSocketService.sharedInstance.event_signal.observeResult { result in
            switch result {
                case .success(let value):
                    handler(value)
                case .failure(let error):
                    print("信号错误 \(error)")
            }
        }
    }
}

final class WebSocketService: WebSocketDelegate {
    
    fileprivate let (message_signal, message_observer) = Signal<String, Error>.pipe()
    fileprivate let (binary_signal, binary_observer) = Signal<Data, Error>.pipe()
    fileprivate let (event_signal, event_observer) = Signal<Bool, Error>.pipe()
    
    private var isConnected:Bool = false
    private var socket = WebSocket.init(request: URLRequest.init(url: URL.init(string: ChatURL.ipAddress + "chat/")!))
    
    // 单例
    static let sharedInstance = WebSocketService()
    
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
