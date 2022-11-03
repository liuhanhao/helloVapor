//
//  ADSChatMessageModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import SQLite

/*
 // MARK: - 生成分隔线
 // FIXME：生成分隔线
 // TODO:
 */

enum ADSMessageType: Int {
    case ADSMessageTypeSystem = 0, //系统消息
         ADSMessageTypeText,       //文本消息
         ADSMessageTypeImage,      //图片消息
         ADSMessageTypeVoice,      //声音消息
         ADSMessageTypeVideo      //视频消息
}

enum ADSMessageSendType: Int {
    case WZMMessageSendTypeWaiting = 0,//正在发送
         WZMMessageSendTypeSuccess,    //发送成功
         WZMMessageSendTypeFailed     //发送失败
}

@objcMembers class ADSChatMessageModel: ADSChatBaseModel {
    
    // TODO: 消息基本信息
    ///消息id
    var mid: String = String(format:"%.f", ADSChatHelper.nowTimestamp())
    ///发送人id
    var uid: String = ""
    ///发送人昵称
    var name: String = ""
    ///发送人头像
    var avatar: String = ""
    ///文本内容
    var message: String = ""
    ///是否是自己发送
    var sender: Bool = false
    ///是否已读
    var read: Bool = false
    ///消息发送时间戳 <该字段参与数据排序, 不要修改字段名, 为了避开数据库关键字, 故意拼错>
    var timestmp: Int = 0
    ///消息类型
    var msgType: ADSMessageType = ADSMessageType.ADSMessageTypeSystem
    ///消息发送结果
    var sendType: ADSMessageSendType = ADSMessageSendType.WZMMessageSendTypeWaiting
    ///缓存model宽, 优化列表滑动
    var modelW: Double = -1
    ///缓存model高, 优化列表滑动
    var modelH: Double = -1
    
    // TODO: 图片消息
    //图片宽高
    var imgW: Double = 1.0
    var imgH: Double = 1.0
    //原图和缩略图
    var original: String = ""
    var thumbnail: String = ""
    
    // TODO: 声音消息
    //声音地址
    var voiceUrl: String = ""
    //声音时长
    var duration: Double = 0.0
    
    // TODO: 视频消息
    //视频地址
    var videoUrl: String = ""
    //视频封面地址
    var coverUrl: String = ""
    
    var attStr: NSMutableAttributedString {
        set {}
        get {
            var style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
            style.lineSpacing = 2
            
            let att = ADSEmoticonManager.manager().attributedString(aString: self.message)
            att.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 15), range: NSMakeRange(0, att.length))
            att.addAttribute(NSAttributedString.Key.paragraphStyle , value: style, range: NSMakeRange(0, att.length))
            
            return att
        }
    }
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    //缓存图片尺寸
    func handleImageSize() {
        let maxW = ceil(ADSInputHelper.sharedHelper.screenW()*0.32)*1.0
        let maxH = ceil(ADSInputHelper.sharedHelper.screenW()*0.32)*1.0
        let imgScale = self.imgW*1.0/self.imgH
        let viewScale = maxW*1.0/maxH
        
        var w = 0.0
        var h = 0.0
        if imgScale > viewScale {
            w = maxW
            h = self.imgH*maxW*1.0/self.imgW
        } else if imgScale < viewScale {
            h = maxH
            w = self.imgW*maxH*1.0/self.imgH
        } else {
            w = maxW
            h = maxH
        }
        self.imgW = ceil(w)
        self.imgH = ceil(h)+ceil(17.0/self.imgW*h-10)
        if imgScale != viewScale {
            if self.imgW > maxW {
                h = self.imgH*maxW*1.0/self.imgW
                self.imgW = maxW
            }
            if self.imgH > maxH {
                w = self.imgW*maxH*1.0/self.imgH
                h = maxH
            }
            self.imgW = ceil(w)
            self.imgH = ceil(h)
        }
    }
    
    // MARK: - 消息的自定义处理
    ///缓存model尺寸
    func cacheModelSize() -> Void {
        if self.modelH == -1 || self.modelW == -1 {
            if self.msgType == .ADSMessageTypeSystem {
                self.modelH = 20
                self.modelW = ADSInputHelper.sharedHelper.screenW()
            }
            else if self.msgType == .ADSMessageTypeText {
                let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
                let size = self.attStr.boundingRect(with: CGSize.init(width: ADSInputHelper.sharedHelper.screenW() - 127, height: CGFloat.greatestFiniteMagnitude), options: options, context: nil).size
                
                self.modelH = max(ceil(size.height), 30.0)
                self.modelW = max(ceil(size.width), 30.0)
            }
            else if self.msgType == .ADSMessageTypeImage {
                self.handleImageSize()
                self.modelH = self.imgH
                self.modelW = self.imgW
            }
            else if (self.msgType == .ADSMessageTypeVoice) {
                var minW = 60.0
                var dw = 5.2
                if ADSInputHelper.sharedHelper.screenW() > 375 {
                    minW = 70.0
                    dw = 5.6
                }
                if self.duration < 6 {
                    self.modelW = minW+self.duration*dw
                }
                else if self.duration < 11 {
                    self.modelW = minW+dw*5.0+(self.duration-5)*(dw-2)
                }
                else if self.duration < 21 {
                    self.modelW = minW+dw*5+(dw-2)*5+(self.duration-10)*(dw-3)
                }
                else  if self.duration < 61 {
                    self.modelW = minW+dw*5+(dw-2)*5+(dw-3)*10+(self.duration-20)*(dw-4)
                }
                else {
                    self.modelW = minW+dw*5+(dw-2)*5+(dw-3)*10+40*(dw-4)
                }
                self.modelH = 30
            }
            else if (self.msgType == .ADSMessageTypeVideo) {
                self.handleImageSize()
                self.modelH = self.imgH
                self.modelW = self.imgW
            }
        }
        
    }
        
}


struct ChatMessageModelTable {
    private var table: Table!
    private var db: Connection!
    private let id = Expression<Int>("id") // 主键
    private let mid = Expression<String>("mid") ///消息id
    private let uid = Expression<String>("uid") ///发送人id
    private let name = Expression<String>("name")
    private let avatar = Expression<String>("avatar")
    private let message = Expression<String>("message")
    private let sender = Expression<Bool>("sender")
    private let read = Expression<Bool>("read")
    private let timestmp = Expression<Int>("timestmp")
    private let msgType = Expression<Int>("msgType")
    private let sendType = Expression<Int>("sendType")
    private let modelW = Expression<Double>("modelW")
    private let modelH = Expression<Double>("modelH")
    private let imgW = Expression<Double>("imgW")
    private let imgH = Expression<Double>("imgH")
    private let original = Expression<String>("original")
    private let thumbnail = Expression<String>("thumbnail")
    private let voiceUrl = Expression<String>("voiceUrl")
    private let duration = Expression<Double>("duration")
    private let videoUrl = Expression<String>("videoUrl")
    private let coverUrl = Expression<String>("coverUrl")
    
    static func createdTableName(model: ADSChatBaseModel) -> String {
        if let user = model as? ADSChatUserModel {
            return "user_" + user.uid
        } else if let group = model as? ADSChatGroupModel {
            return "group_" + group.gid
        } else if let session = model as? ADSChatSessionModel {
            if session.cluster {
                return "group_" + session.sid
            } else {
                return "user_" + session.sid
            }
        } else {
            return ""
        }
    }
    
    // 一个好友一张表
    init(userModel: ADSChatUserModel) {
        let tableName = Self.createdTableName(model: userModel)
        table = Table(tableName) //表名
        createdsqlite3(tableName: tableName)
    }

    // 创建聊天组别表
    init(groupModel: ADSChatGroupModel) {
        let tableName = Self.createdTableName(model: groupModel)
        table = Table(tableName) //表名
        createdsqlite3(tableName: tableName)
    }
    
    // 根据sessionModel 创建表
    init(sessionModel: ADSChatSessionModel) {
        let tableName = Self.createdTableName(model: sessionModel)
        table = Table(tableName) //表名
        createdsqlite3(tableName: tableName)
    }
    
    // 创建数据库文件
    mutating func createdsqlite3(tableName: String) {
        // 设置数据库路径
        let sqlFilePath = NSHomeDirectory() + "/Documents/" + tableName + ".sqlite3"
        do {
            db = try Connection(sqlFilePath) // 连接数据库
            // 创建表
            try db.run(table.create(block: { (table) in
                table.column(id, primaryKey: true)
                table.column(mid)
                table.column(uid)
                table.column(name)
                table.column(avatar)
                table.column(message)
                table.column(sender)
                table.column(read)
                table.column(timestmp)
                table.column(msgType)
                table.column(sendType)
                table.column(modelW)
                table.column(modelH)
                table.column(imgW)
                table.column(imgH)
                table.column(original)
                table.column(thumbnail)
                table.column(voiceUrl)
                table.column(duration)
                table.column(videoUrl)
                table.column(coverUrl)
            }))
        } catch {
            print("数据库表已经存在: \(error)")
        }
    }
    
    // 添加一条信息
    func insertMessageModel(messageModel: ADSChatMessageModel) {
        // 用户信息中没有ID就不存入数据库(被列为无效用户)
        guard messageModel.mid.count > 0 else {
            print("没有ID信息,视为无效用户")
            return;
        }
        // 查找数据库中是否有该用户,如果有则执行修改操作
        guard readMessageModel(messageId: messageModel.mid) == nil else {
            print("已存在改用户,接下来更新此用户数据")
            updateMessageModel(messageId: messageModel.mid, messageModel: messageModel)
            return
        }
        let insert = table.insert(mid <- messageModel.mid,
                                  uid <- messageModel.uid,
                                  name <- messageModel.name,
                                  avatar <- messageModel.avatar,
                                  message <- messageModel.message,
                                  sender <- messageModel.sender,
                                  read <- messageModel.read,
                                  timestmp <- messageModel.timestmp,
                                  msgType <- messageModel.msgType.rawValue,
                                  sendType <- messageModel.sendType.rawValue,
                                  modelW <- messageModel.modelW,
                                  modelH <- messageModel.modelH,
                                  imgW <- messageModel.imgW,
                                  imgH <- messageModel.imgH,
                                  original <- messageModel.original,
                                  thumbnail <- messageModel.thumbnail,
                                  voiceUrl <- messageModel.voiceUrl,
                                  duration <- messageModel.duration,
                                  videoUrl <- messageModel.videoUrl,
                                  coverUrl <- messageModel.coverUrl)
        
        do {
            let num = try db.run(insert)
            print("insertUser\(num)")
        } catch {
            print("增加用户到数据库出错: \(error)")
        }
        
    }
    
    // 删除指定用户信息
    func deleteMessageModel(messageId: String) {
        let currUser = table.filter(mid == messageId)
        do {
            let num = try db.run(currUser.delete())
            print("deleteUser\(num)")
        } catch {
            print("删除用户信息出错: \(error)")
        }
    }
    
    // 更新指定用户信息
    func updateMessageModel(messageId: String, messageModel: ADSChatMessageModel) {
        let currUser = table.filter(mid == messageId)
        let update = currUser.update(mid <- messageModel.mid,
                                     uid <- messageModel.uid,
                                     name <- messageModel.name,
                                     avatar <- messageModel.avatar,
                                     message <- messageModel.message,
                                     sender <- messageModel.sender,
                                     read <- messageModel.read,
                                     timestmp <- messageModel.timestmp,
                                     msgType <- messageModel.msgType.rawValue,
                                     sendType <- messageModel.sendType.rawValue,
                                     modelW <- messageModel.modelW,
                                     modelH <- messageModel.modelH,
                                     imgW <- messageModel.imgW,
                                     imgH <- messageModel.imgH,
                                     original <- messageModel.original,
                                     thumbnail <- messageModel.thumbnail,
                                     voiceUrl <- messageModel.voiceUrl,
                                     duration <- messageModel.duration,
                                     videoUrl <- messageModel.videoUrl,
                                     coverUrl <- messageModel.coverUrl)
        do {
            let num = try db.run(update)
            print("updateUser\(num)")
        } catch {
            print("updateUser\(error)")
        }
    }
    
    // 查询指定用户信息
    func readMessageModel(messageId: String) -> ADSChatMessageModel? {
        let messageModel: ADSChatMessageModel = ADSChatMessageModel.init()
        for messageM in try! db.prepare(table) {
            if messageM[mid] == messageId {
                messageModel.mid = messageM[mid]
                messageModel.uid = messageM[uid]
                messageModel.name = messageM[name]
                messageModel.avatar = messageM[avatar]
                messageModel.message = messageM[message]
                messageModel.sender = messageM[sender]
                messageModel.read = messageM[read]
                messageModel.timestmp = messageM[timestmp]
                messageModel.msgType = ADSMessageType.init(rawValue: messageM[msgType])!
                messageModel.sendType = ADSMessageSendType.init(rawValue: messageM[sendType])!
                messageModel.modelW = messageM[modelW]
                messageModel.modelH = messageM[modelH]
                messageModel.imgW = messageM[imgW]
                messageModel.imgH = messageM[imgH]
                messageModel.original = messageM[original]
                messageModel.thumbnail = messageM[thumbnail]
                messageModel.voiceUrl = messageM[voiceUrl]
                messageModel.duration = messageM[duration]
                messageModel.videoUrl = messageM[videoUrl]
                messageModel.coverUrl = messageM[coverUrl]
                return messageModel
            }
        }
        return nil
    }
    
    // 查询所有用户信息
    func readAllMessageModels() -> [ADSChatMessageModel] {
        var usersArr: [ADSChatMessageModel] = [ADSChatMessageModel]()
        let messageModel: ADSChatMessageModel = ADSChatMessageModel()
        for messageM in try! db.prepare(table) {
            messageModel.mid = messageM[mid]
            messageModel.uid = messageM[uid]
            messageModel.name = messageM[name]
            messageModel.avatar = messageM[avatar]
            messageModel.message = messageM[message]
            messageModel.sender = messageM[sender]
            messageModel.read = messageM[read]
            messageModel.timestmp = messageM[timestmp]
            messageModel.msgType = ADSMessageType.init(rawValue: messageM[msgType])!
            messageModel.sendType = ADSMessageSendType.init(rawValue: messageM[sendType])!
            messageModel.modelW = messageM[modelW]
            messageModel.modelH = messageM[modelH]
            messageModel.imgW = messageM[imgW]
            messageModel.imgH = messageM[imgH]
            messageModel.original = messageM[original]
            messageModel.thumbnail = messageM[thumbnail]
            messageModel.voiceUrl = messageM[voiceUrl]
            messageModel.duration = messageM[duration]
            messageModel.videoUrl = messageM[videoUrl]
            messageModel.coverUrl = messageM[coverUrl]
            usersArr.append(messageModel)
        }
        return usersArr
    }
    
    // 根据时间排序进行翻页
    func readMessages(orderBy desc: Bool, page: Int) -> [ADSChatMessageModel] {
        var usersArr: [ADSChatMessageModel] = [ADSChatMessageModel]()
        
        var orderBy: [Expressible] = [timestmp.desc]
        if desc == false {
            orderBy = [timestmp.asc]
        }
        // 构造查询语句 翻页
        let sql = self.table.order(orderBy).limit(10)
        let messageModel: ADSChatMessageModel = ADSChatMessageModel()
        for messageM in try! db.prepare(sql) {
            messageModel.mid = messageM[mid]
            messageModel.uid = messageM[uid]
            messageModel.name = messageM[name]
            messageModel.avatar = messageM[avatar]
            messageModel.message = messageM[message]
            messageModel.sender = messageM[sender]
            messageModel.read = messageM[read]
            messageModel.timestmp = messageM[timestmp]
            messageModel.msgType = ADSMessageType.init(rawValue: messageM[msgType])!
            messageModel.sendType = ADSMessageSendType.init(rawValue: messageM[sendType])!
            messageModel.modelW = messageM[modelW]
            messageModel.modelH = messageM[modelH]
            messageModel.imgW = messageM[imgW]
            messageModel.imgH = messageM[imgH]
            messageModel.original = messageM[original]
            messageModel.thumbnail = messageM[thumbnail]
            messageModel.voiceUrl = messageM[voiceUrl]
            messageModel.duration = messageM[duration]
            messageModel.videoUrl = messageM[videoUrl]
            messageModel.coverUrl = messageM[coverUrl]
            usersArr.append(messageModel)
        }
        return usersArr
    }
    
    // 事务的写法
    func transaction(messageId: String) -> ADSChatMessageModel? {
        
        var model:ADSChatMessageModel? = nil
        do {
            try db.transaction {
                model = self.readMessageModel(messageId: messageId)
            }
        }
        catch {
            print("updateUser\(error)")
        }
        
        return model
    }
}
