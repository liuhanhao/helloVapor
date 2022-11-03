//
//  WZMChatDBManager.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class WZMChatDBManager: NSObject {

    lazy var chatSqliteManager: WZMChatSqliteManager = {
        return WZMChatSqliteManager.shared
    }()
    ///输入框草稿
    var draftDic:[String:String] = [:]
    
    //第一种方式：静态常量，所有地方用到的都是同一个
    static let shared = WZMChatDBManager()
    //将保留字用作标识符，请在其前后加上反引号,default是一个快速的保留关键字
    static let `default` = WZMChatDBManager()
    
    //第二种方式
    class func defaultManager() -> WZMChatDBManager {
        return self.default
    }
    
    private override init() {
        super.init()
    }
    
    ///草稿
    func draft(model: ADSChatBaseModel) -> String {
        if let userModel = model as? ADSChatUserModel { // 单聊
            return self.draftDic[userModel.uid] ?? ""
        } else if let groupModel = model as? ADSChatGroupModel { // 群聊
            return self.draftDic[groupModel.gid] ?? ""
        } else {
            return ""
        }
    }

    //删除草稿
    func removeDraft(model: ADSChatBaseModel) {
        if let userModel = model as? ADSChatUserModel { // 单聊
            self.draftDic[userModel.uid] = ""
        } else if let groupModel = model as? ADSChatGroupModel { // 群聊
            self.draftDic[groupModel.gid] = ""
        }
    }

    //保存草稿
    func setDraft(model: ADSChatBaseModel, draft: String) {
        if let userModel = model as? ADSChatUserModel { // 单聊
            self.draftDic[userModel.uid] = draft
        } else if let groupModel = model as? ADSChatGroupModel { // 群聊
            self.draftDic[groupModel.gid] = draft
        }
    }
//
//    #pragma mark - user表操纵
//    //所有用户
//    - (NSMutableArray *)users {
//        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",WZM_USER];
//        NSArray *list = [[WZMChatSqliteManager shareManager] selectWithSql:sql];
//        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:list.count];
//        for (NSDictionary *dic in list) {
//            WZMChatUserModel *model = [WZMChatUserModel modelWithDic:dic];
//            [arr addObject:model];
//        }
//        return arr;
//    }
//
//    //添加用户
//    - (void)insertUserModel:(WZMChatUserModel *)model {
//        [[WZMChatSqliteManager shareManager] insertModel:model tableName:WZM_USER];
//    }
//
//    //更新用户
//    - (void)updateUserModel:(WZMChatUserModel *)model {
//        [[WZMChatSqliteManager shareManager] updateModel:model tableName:WZM_USER primkey:@"uid"];
//    }
//
//    //查询用户
//    - (WZMChatUserModel *)selectUserModel:(NSString *)uid {
//        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE uid = '%@'",WZM_USER,uid];
//        NSArray *list = [[WZMChatSqliteManager shareManager] selectWithSql:sql];
//        if (list.count > 0) {
//            WZMChatUserModel *model = [WZMChatUserModel modelWithDic:list.firstObject];
//            return model;
//        }
//        return nil;
//    }
//
//    //删除用户
//    - (void)deleteUserModel:(NSString *)uid {
//        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE uid = '%@'",WZM_USER,uid];
//        [[WZMChatSqliteManager shareManager] execute:sql];
//        //同时删除对应的会话和消息记录
//        [self deleteSessionModel:uid];
//        [self deleteMessageWithUid:uid];
//    }
//
//    #pragma mark - group表操纵
//    //所有群
//    - (NSMutableArray *)groups {
//        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",WZM_GROUP];
//        NSArray *list = [[WZMChatSqliteManager shareManager] selectWithSql:sql];
//        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:list.count];
//        for (NSDictionary *dic in list) {
//            WZMChatGroupModel *model = [WZMChatGroupModel modelWithDic:dic];
//            [arr addObject:model];
//        }
//        return arr;
//    }
//
//    //添加群
//    - (void)insertGroupModel:(WZMChatGroupModel *)model {
//        [[WZMChatSqliteManager shareManager] insertModel:model tableName:WZM_GROUP];
//    }
//
//    //更新群
//    - (void)updateGroupModel:(WZMChatGroupModel *)model {
//        [[WZMChatSqliteManager shareManager] updateModel:model tableName:WZM_GROUP primkey:@"gid"];
//    }
//
//    //查询群
//    - (WZMChatGroupModel *)selectGroupModel:(NSString *)gid {
//        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE gid = '%@'",WZM_GROUP,gid];
//        NSArray *list = [[WZMChatSqliteManager shareManager] selectWithSql:sql];
//        if (list.count > 0) {
//            WZMChatGroupModel *model = [WZMChatGroupModel modelWithDic:list.firstObject];
//            return model;
//        }
//        return nil;
//    }
//
//    //删除群
//    - (void)deleteGroupModel:(NSString *)gid {
//        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE gid = '%@'",WZM_GROUP,gid];
//        [[WZMChatSqliteManager shareManager] execute:sql];
//        //同时删除对应的会话和消息记录
//        [self deleteSessionModel:gid];
//        [self deleteMessageWithGid:gid];
//    }
//
//    #pragma mark - session表操纵
//    //所有会话
//    - (NSMutableArray *)sessions {
//        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",WZM_SESSION];
//        NSArray *list = [[WZMChatSqliteManager shareManager] selectWithSql:sql];
//        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:list.count];
//        for (NSDictionary *dic in list) {
//            WZMChatSessionModel *model = [WZMChatSessionModel modelWithDic:dic];
//            [arr addObject:model];
//        }
//        [arr sortUsingSelector:@selector(compareOtherModel:)];
//        return arr;
//    }
//
//    //添加会话
//    - (void)insertSessionModel:(WZMChatSessionModel *)model {
//        [[WZMChatSqliteManager shareManager] insertModel:model tableName:WZM_SESSION];
//    }
//
//    //更新会话
//    - (void)updateSessionModel:(WZMChatSessionModel *)model {
//        [[WZMChatSqliteManager shareManager] updateModel:model tableName:WZM_SESSION primkey:@"sid"];
//    }
//
//    //查询私聊会话
//    - (WZMChatSessionModel *)selectSessionModelWithUser:(WZMChatUserModel *)userModel {
//        return [self selectSessionModel:userModel];
//    }
//
//    //查询群聊会话
//    - (WZMChatSessionModel *)selectSessionModelWithGroup:(WZMChatGroupModel *)groupModel {
//        return [self selectSessionModel:groupModel];
//    }
//
//    //private
//    - (WZMChatSessionModel *)selectSessionModel:(WZMChatBaseModel *)model {
//        NSString *sid, *name, *avatar; BOOL isGroup;
//        if ([model isKindOfClass:[WZMChatUserModel class]]) {
//            WZMChatUserModel *user = (WZMChatUserModel *)model;
//            sid = user.uid;
//            name = user.name;
//            avatar = user.avatar;
//            isGroup = NO;
//        }
//        else {
//            WZMChatGroupModel *group = (WZMChatGroupModel *)model;
//            sid = group.gid;
//            name = group.name;
//            avatar = group.avatar;
//            isGroup = YES;
//        }
//        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE sid = '%@'",WZM_SESSION,sid];
//        NSArray *list = [[WZMChatSqliteManager shareManager] selectWithSql:sql];
//        WZMChatSessionModel *session;
//        if (list.count > 0) {
//            session = [WZMChatSessionModel modelWithDic:list.firstObject];
//            session.sid = sid;
//            session.name = name;
//            session.avatar = avatar;
//            session.cluster = isGroup;
//        }
//        else {
//            //创建会话,并插入数据库
//            session = [[WZMChatSessionModel alloc] init];
//            session.sid = sid;
//            session.name = name;
//            session.avatar = avatar;
//            session.cluster = isGroup;
//            [self insertSessionModel:session];
//        }
//        return session;
//    }
//
//    //删除会话
//    - (void)deleteSessionModel:(NSString *)sid {
//        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE sid = '%@'",WZM_SESSION,sid];
//        [[WZMChatSqliteManager shareManager] execute:sql];
//    }
//
//    ///查询会话对应的用户或者群聊
//    - (WZMChatBaseModel *)selectChatModel:(WZMChatSessionModel *)model {
//        if (model.isCluster) {
//            return [self selectGroupModel:model.sid];
//        }
//        else {
//            return [self selectUserModel:model.sid];
//        }
//    }
//
//    //查询会话对应的用户
//    - (WZMChatUserModel *)selectChatUserModel:(WZMChatSessionModel *)model {
//        return [self selectUserModel:model.sid];
//    }
//
//    //查询会话对应的群聊
//    - (WZMChatGroupModel *)selectChatGroupModel:(WZMChatSessionModel *)model {
//        return [self selectGroupModel:model.sid];
//    }
//
//    #pragma mark - message表操纵
//    //删除私聊消息记录
//    - (void)deleteMessageWithUid:(NSString *)uid {
//        NSString *tableName = [self tableNameWithUid:uid];
//        [[WZMChatSqliteManager shareManager] deleteTableName:tableName];
//    }
//
//    //删除群聊消息记录
//    - (void)deleteMessageWithGid:(NSString *)gid {
//        NSString *tableName = [self tableNameWithUid:gid];
//        [[WZMChatSqliteManager shareManager] deleteTableName:tableName];
//    }
//
    
//
//    //插入私聊消息
//    - (void)insertMessage:(WZMChatMessageModel *)message chatWithUser:(WZMChatUserModel *)model {
//        [self insertMessage:message chatWithModel:model];
//    }
//
//    //插入群聊消息
//    - (void)insertMessage:(WZMChatMessageModel *)message chatWithGroup:(WZMChatGroupModel *)model {
//        [self insertMessage:message chatWithModel:model];
//    }
//
//    //private
//    - (void)insertMessage:(WZMChatMessageModel *)message chatWithModel:(WZMChatBaseModel *)model{
//        WZMChatSessionModel *session = [self selectSessionModel:model];
//        session.lastMsg = message.message;
//        session.lastTimestmp = message.timestmp;
//        [self updateSessionModel:session];
//
//        NSString *tableName = [self tableNameWithModel:model];
//        [[WZMChatSqliteManager shareManager] createTableName:tableName modelClass:[message class] hasId:YES];
//        [[WZMChatSqliteManager shareManager] insertModel:message tableName:tableName];
//    }
//
//    //更新私聊消息
//    - (void)updateMessageModel:(WZMChatMessageModel *)message chatWithUser:(WZMChatUserModel *)model {
//        NSString *tableName = [self tableNameWithModel:model];
//        [[WZMChatSqliteManager shareManager] updateModel:message tableName:tableName primkey:@"mid"];
//    }
//
//    //更新群聊消息
//    - (void)updateMessageModel:(WZMChatMessageModel *)message chatWithGroup:(WZMChatGroupModel *)model {
//        NSString *tableName = [self tableNameWithModel:model];
//        [[WZMChatSqliteManager shareManager] updateModel:message tableName:tableName primkey:@"mid"];
//    }
//
//    //删除私聊消息
//    - (void)deleteMessageModel:(WZMChatMessageModel *)message chatWithUser:(WZMChatUserModel *)model {
//        NSString *tableName = [self tableNameWithModel:model];
//        [[WZMChatSqliteManager shareManager] deleteModel:message tableName:tableName primkey:@"mid"];
//    }
//
//    //删除群聊消息
//    - (void)deleteMessageModel:(WZMChatMessageModel *)message chatWithGroup:(WZMChatGroupModel *)model {
//        NSString *tableName = [self tableNameWithModel:model];
//        [[WZMChatSqliteManager shareManager] deleteModel:message tableName:tableName primkey:@"mid"];
//    }
//
    
    
    // 创建用户/群聊消息表，以用户的userid作为表名
    func createMessageTableName(model: ADSChatBaseModel) -> ChatMessageModelTable {
        return self.chatSqliteManager.getMessageTable(model: model)!
    }
    
    // 删除用户/群聊消息表
    func deleteMessageTableName(model: ADSChatBaseModel) -> Bool {
        return true
    }
    
    
}
