//
//  ADSChatMessageManager.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class ADSChatMessageManager: NSObject {

    // 创建消息模型
    // 创建系统消息
    static func createSystemMessage(userModel: ADSChatUserModel,
                                    message: String,
                                    isSender: Bool) -> ADSChatMessageModel {
        
        let msgModel = ADSChatMessageModel.init()
        msgModel.msgType = ADSMessageType.ADSMessageTypeSystem
        msgModel.message = message
        self.setConfig(msgModel: msgModel, userModel: userModel, isSender: isSender)
        return msgModel
    }
    
    // 创建图片消息
    static func createImageMessage(userModel: ADSChatUserModel,
                                   thumbnail: String,
                                   original: String,
                                   thumImage: UIImage,
                                   oriImage: UIImage,
                                   isSender: Bool) -> ADSChatMessageModel {
        
        let msgModel = ADSChatMessageModel.init()
        msgModel.msgType = ADSMessageType.ADSMessageTypeImage
        msgModel.message = "[图片]"
        msgModel.thumbnail = thumbnail
        msgModel.original  = original
        msgModel.imgW = oriImage.size.width
        msgModel.imgH = oriImage.size.height
        //将图片保存到本地
        let _ = ADSChatHelper.sharedHelper.setObj(obj: oriImage, forKey: original)
        let _ = ADSChatHelper.sharedHelper.setObj(obj: thumImage, forKey: thumbnail)
        self.setConfig(msgModel: msgModel, userModel: userModel, isSender: isSender)
        return msgModel
    }
    
    //创建文本消息
    static func createTextMessage(userModel: ADSChatUserModel,
                                  message: String,
                                  isSender: Bool) -> ADSChatMessageModel {
        
        let msgModel = ADSChatMessageModel.init()
        msgModel.msgType = ADSMessageType.ADSMessageTypeText
        msgModel.message = message
        self.setConfig(msgModel: msgModel, userModel: userModel, isSender: isSender)
        return msgModel
    }
    
    //创建录音消息
    static func createVoiceMessage(userModel: ADSChatUserModel,
                                   duration: Double,
                                   voiceUrl:String,
                                   isSender: Bool) -> ADSChatMessageModel {
        
        let msgModel = ADSChatMessageModel.init()
        msgModel.msgType = ADSMessageType.ADSMessageTypeVoice
        msgModel.message = "[语音]"
        msgModel.duration = duration
        msgModel.voiceUrl = voiceUrl
        self.setConfig(msgModel: msgModel, userModel: userModel, isSender: isSender)
        return msgModel
    }
    
    // 创建视频消息
    static func createVideoMessage(userModel: ADSChatUserModel,
                                   videoUrl:String,
                                   coverUrl: String,
                                   coverImage: UIImage,
                                   isSender: Bool) -> ADSChatMessageModel {
        
        let msgModel = ADSChatMessageModel.init()
        msgModel.msgType = ADSMessageType.ADSMessageTypeVideo
        msgModel.message = "[视频]"
        msgModel.videoUrl = videoUrl
        msgModel.coverUrl = coverUrl
        msgModel.imgW = coverImage.size.width
        msgModel.imgH = coverImage.size.height
        //将封面图片保存到本地
        ADSChatHelper.sharedHelper.setObj(obj: coverImage, forKey: coverUrl)
        self.setConfig(msgModel: msgModel, userModel: userModel, isSender: isSender)
        return msgModel
    }
    
    class func setConfig(msgModel: ADSChatMessageModel, userModel: ADSChatUserModel, isSender: Bool) {
        if isSender {
            msgModel.uid = ADSShareInfoSingleton.shared.shareInfo.uid
            msgModel.name = ADSShareInfoSingleton.shared.shareInfo.name
            msgModel.avatar = ADSShareInfoSingleton.shared.shareInfo.avatar
        } else {
            msgModel.uid = userModel.uid
            msgModel.name = userModel.name
            msgModel.avatar = userModel.avatar
        }
        
        msgModel.sender = isSender
        msgModel.sendType = ADSMessageSendType.WZMMessageSendTypeWaiting
        msgModel.timestmp = Int(ADSChatHelper.nowTimestamp())
    }
    
}
