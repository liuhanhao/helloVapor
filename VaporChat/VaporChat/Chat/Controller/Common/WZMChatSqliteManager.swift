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
    fileprivate var messageTables: [String : ChatMessageModelTable] = [:]
    
    //第二种方式
    class func defaultManager() -> WZMChatSqliteManager {
        return self.default
    }
    
    private override init() {
        super.init()
    }
    
    func getMessageTable(model: ADSChatBaseModel) -> ChatMessageModelTable? {
        if let user = model as? ADSChatUserModel {
            let tableName = ChatMessageModelTable.createdTableName(model: user)
            
            guard let messageTable:ChatMessageModelTable = self.messageTables[tableName] else {
                return ChatMessageModelTable.init(userModel: user)
            }
            
            // 保存到messageTables中
            self.messageTables[tableName] = messageTable
            return messageTable
        } else if let group = model as? ADSChatGroupModel {
            let tableName = ChatMessageModelTable.createdTableName(model: group)
            
            guard let messageTable:ChatMessageModelTable = self.messageTables[tableName] else {
                return ChatMessageModelTable.init(groupModel: group)
            }
            
            // 保存到messageTables中
            self.messageTables[tableName] = messageTable
            return messageTable
        } else if let session = model as? ADSChatSessionModel {
            let tableName = ChatMessageModelTable.createdTableName(model: session)
            
            guard let messageTable:ChatMessageModelTable = self.messageTables[tableName] else {
                return ChatMessageModelTable.init(sessionModel: session)
            }
            
            // 保存到messageTables中
            self.messageTables[tableName] = messageTable
            return messageTable
        } else {
            return nil
        }
    }
    
    //私聊消息
    func messagesWithUser(model: ADSChatUserModel, page: Int) -> [ADSChatMessageModel] {
        return self.messagesWithModel(model: model, page: page)
    }

    //群聊消息
    func messagesWithGroup(model: ADSChatGroupModel, page: Int) -> [ADSChatMessageModel] {
        return self.messagesWithModel(model: model, page: page)
    }
    
    //private
    func messagesWithModel(model: ADSChatBaseModel, page: Int) -> [ADSChatMessageModel] {
        if let messageTable = self.getMessageTable(model: model) {
            return messageTable.readMessages(orderBy: true, page: page)
        }
        else {
            return []
        }
    }
    
}
