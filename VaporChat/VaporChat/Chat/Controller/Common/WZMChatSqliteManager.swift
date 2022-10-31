//
//  WZMChatSqliteManager.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class WZMChatSqliteManager: NSObject {
    
    //第一种方式：静态常量，所有地方用到的都是同一个
    static let shared = WZMChatSqliteManager()
    //将保留字用作标识符，请在其前后加上反引号,default是一个快速的保留关键字
    static let `default` = WZMChatSqliteManager()
    
    let chatUserTable: ChatUserModelTable = ChatUserModelTable()
    let chatGroupTable: ChatGroupModelTable = ChatGroupModelTable()
    let chatSessionTable: ChatSessionModelTable = ChatSessionModelTable()
    // userid作为key
    var messageTables: [String : ChatMessageModelTable] = [:]
    
    //第二种方式
    class func defaultManager() -> WZMChatSqliteManager {
        return self.default
    }
    
    private override init() {
        super.init()
    }
    
    
    
}
