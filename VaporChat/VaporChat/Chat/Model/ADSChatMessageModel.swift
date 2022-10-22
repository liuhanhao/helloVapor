//
//  ADSChatMessageModel.swift
//  VaporChat
//
//  Created by admin on 2022/9/15.
//

import UIKit
import ObjectMapper

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
    var uid: String?
    ///发送人昵称
    var name: String?
    ///发送人头像
    var avatar: String?
    ///文本内容
    var message: String = ""
    ///是否是自己发送
    var sender: Bool?
    ///是否已读
    var read: Bool?
    ///消息发送时间戳 <该字段参与数据排序, 不要修改字段名, 为了避开数据库关键字, 故意拼错>
    var timestmp: Int?
    ///消息类型
    var msgType: ADSMessageType?
    ///消息发送结果
    var sendType: ADSMessageSendType?
    ///缓存model宽, 优化列表滑动
    var modelW: Int = -1
    ///缓存model高, 优化列表滑动
    var modelH: Int = -1
    
    // TODO: 图片消息
    //图片宽高
    var imgW: CGFloat = 1.0
    var imgH: CGFloat = 1.0
    //原图和缩略图
    var original: String?
    var thumbnail: String?
    
    // TODO: 声音消息
    //声音地址
    var voiceUrl: String?
    //声音时长
    var duration: CGFloat = 0.0
    
    // TODO: 视频消息
    //视频地址
    var videoUrl: String?
    //视频封面地址
    var coverUrl: String?
    
    lazy var attStr = {
        var style: NSMutableParagraphStyle = NSMutableParagraphStyle.init()
        style.lineSpacing = 2
        
        let att = ADSEmoticonManager.manager().attributedString(aString: self.message)
        att.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 15), range: NSMakeRange(0, att.length))
        att.addAttribute(NSAttributedString.Key.paragraphStyle , value: style, range: NSMakeRange(0, att.length))
        
        return att
    }()
    
    required init?(map: Map) {
        super.init(map: map)
        //        // 检查 JSON 里是否有一定要有的 "name" 属性
        //        if map.JSON["name"] == nil {
        //            return nil
        //        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // Mappable
    override func mapping(map: Map) { // 支持点语法
        super.mapping(map: map)
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
                self.modelW = Int(ADSInputHelper.sharedHelper.screenW())
            }
            else if self.msgType == .ADSMessageTypeText {
                let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
                let size = self.attStr.boundingRect(with: CGSize.init(width: ADSInputHelper.sharedHelper.screenW() - 127, height: CGFloat.greatestFiniteMagnitude), options: options, context: nil).size
                
                self.modelH = Int(max(ceil(size.height), 30.0))
                self.modelW = Int(max(ceil(size.width), 30.0))
            }
            else if self.msgType == .ADSMessageTypeImage {
                self.handleImageSize()
                self.modelH = Int(self.imgH)
                self.modelW = Int(self.imgW)
            }
            else if (self.msgType == .ADSMessageTypeVoice) {
                var minW = 60.0
                var dw = 5.2
                if ADSInputHelper.sharedHelper.screenW() > 375 {
                    minW = 70.0
                    dw = 5.6
                }
                if self.duration < 6 {
                    self.modelW = Int(minW+self.duration*dw)
                }
                else if self.duration < 11 {
                    self.modelW = Int(minW+dw*5.0+(self.duration-5)*(dw-2))
                }
                else if self.duration < 21 {
                    self.modelW = Int(minW+dw*5+(dw-2)*5+(self.duration-10)*(dw-3))
                }
                else  if self.duration < 61 {
                    self.modelW = Int(minW+dw*5+(dw-2)*5+(dw-3)*10+(self.duration-20)*(dw-4))
                }
                else {
                    self.modelW = Int(minW+dw*5+(dw-2)*5+(dw-3)*10+40*(dw-4))
                }
                self.modelH = 30
            }
            else if (self.msgType == .ADSMessageTypeVideo) {
                self.handleImageSize()
                self.modelH = Int(self.imgH)
                self.modelW = Int(self.imgW)
            }
        }
        
    }
    
        
}
