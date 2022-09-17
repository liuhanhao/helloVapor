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

class ADSChatMessageModel: ADSChatBaseModel {

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
    var message: String?
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
    var imgW: Int?
    var imgH: Int?
    //原图和缩略图
    var original: String?
    var thumbnail: String?

    // TODO: 声音消息
    //声音地址
    var voiceUrl: String?
    //声音时长
    var duration: Int?

    // TODO: 视频消息
    //视频地址
    var videoUrl: String?
    //视频封面地址
    var coverUrl: String?
    
    required init?(map: Map) {
        super.init(map: map)
//        // 检查 JSON 里是否有一定要有的 "name" 属性
//        if map.JSON["name"] == nil {
//            return nil
//        }
    }

    // Mappable
    override func mapping(map: Map) { // 支持点语法
        super.mapping(map: map)
    }
    
//    // 富文本
//    var attributedString: NSAttributedString {
//        set {
//
//        }
//        get {
//            var style = NSMutableParagraphStyle.init()
//            style.lineSpacing = 2
//            let a = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15),
//                     NSAttributedString.Key.paragraphStyle: style
//            ]
//            let att = NSMutableAttributedString.init(string: <#T##String#>, attributes: <#T##[NSAttributedString.Key : Any]?#>)
//        }
//    }
//
//    // MARK: - 消息的自定义处理
//    ///缓存model尺寸
//    func cacheModelSize() -> Void {
//        if (self.modelH == -1 || self.modelW == -1) {
//            if (self.msgType == .ADSMessageTypeSystem) {
//                self.modelH = 20;
//                self.modelW = ADSInputHelper.sharedHelper.screenW();
//            }
//            else if (self.msgType == .ADSMessageTypeText) {
//                let size = self.att
//                CGSize size = [[self attributedString] boundingRectWithSize:CGSizeMake((CHAT_SCREEN_WIDTH-127), CGFLOAT_MAX)
//                                                                    options:NSStringDrawingUsesLineFragmentOrigin
//                                                                    context:nil].size;
//                self.modelH = MAX(ceil(size.height), 30);
//                self.modelW = MAX(ceil(size.width), 30);
//            }
//            else if (self.msgType == WZMMessageTypeImage) {
//                [self handleImageSize];
//                self.modelH = self.imgH;
//                self.modelW = self.imgW;
//            }
//            else if (self.msgType == WZMMessageTypeVoice) {
//                CGFloat minW = 60;
//                CGFloat dw = 5.2;
//                if (CHAT_SCREEN_WIDTH > 375) {
//                    minW = 70;
//                    dw = 5.6;
//                }
//                if (self.duration < 6) {
//                    self.modelW = minW+self.duration*dw;
//                }
//                else if (self.duration < 11) {
//                    self.modelW = minW+dw*5+(self.duration-5)*(dw-2);
//                }
//                else if (self.duration < 21) {
//                    self.modelW = minW+dw*5+(dw-2)*5+(self.duration-10)*(dw-3);
//                }
//                else  if (self.duration < 61) {
//                    self.modelW = minW+dw*5+(dw-2)*5+(dw-3)*10+(self.duration-20)*(dw-4);
//                }
//                else {
//                    self.modelW = minW+dw*5+(dw-2)*5+(dw-3)*10+40*(dw-4);
//                }
//                self.modelH = 30;
//            }
//            else if (self.msgType == WZMMessageTypeVideo) {
//                [self handleImageSize];
//                self.modelH = self.imgH;
//                self.modelW = self.imgW;
//            }
//        }
//    }
}
