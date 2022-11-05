//
//  ADSChatMessageCell.swift
//  VaporChat
//
//  Created by admin on 2022/11/1.
//

import Foundation
import UIKit

class ADSChatMessageCell: ADSChatBaseCell {

    var nickLabel: UILabel = UILabel.init()
    var avatarImageView: UIImageView = UIImageView.init()
    var bubbleImageView: UIImageView = UIImageView.init()
    var activityView: UIActivityIndicatorView = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.gray)
    
    var contentRect: CGRect = CGRect.zero
    
    var retryBtn: ADSChatBtn = ADSChatBtn.chatButtonWithType(type: ADSChatButtonType.ADSChatButtonTypeRetry)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(nickLabel)
        self.contentView.addSubview(bubbleImageView)
        self.contentView.addSubview(activityView)
        self.contentView.addSubview(retryBtn)
        self.contentView.addSubview(avatarImageView)
        
        avatarImageView.layer.masksToBounds = true
        avatarImageView.layer.cornerRadius = 20
        
        nickLabel.textColor = UIColor.gray
        nickLabel.textAlignment = NSTextAlignment.center
        nickLabel.font = UIFont.systemFont(ofSize: 12)

        retryBtn.setImage(UIImage.init(named: "wzm_chat_retry"), for: UIControl.State.normal)
        retryBtn.addTarget(self, action: #selector(self.retryBtnClick(btn:)), for: UIControl.Event.touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func retryBtnClick(btn: UIButton) {
        
    }
    
    override func setConfig(model: ADSChatMessageModel, isShowName: Bool) {
        super.setConfig(model: model)
        
        if model.sender {
            //头像
            self.avatarImageView.frame = CGRect.init(x: self.CHAT_SCREEN_WIDTH() - 50.0, y: 40, width: 40, height: 40)
            //可改成网络图片
            let _ = ADSChatHelper.sharedHelper.getImageWithUrl(urlString: model.avatar, isUseCatch: true) { image in
                self.avatarImageView.image = image
            }
            
            //昵称
            self.nickLabel.frame = CGRect.init(x: self.avatarImageView.chat_minX-110, y: 5, width: 100, height: 20)
            self.nickLabel.text = model.name
            self.nickLabel.textAlignment = NSTextAlignment.right
            
            if isShowName {
                self.nickLabel.isHidden = false
                //聊天气泡
                self.bubbleImageView.frame = CGRect.init(x: self.avatarImageView.chat_minX-model.modelW-22.0, y: self.nickLabel.chat_maxY, width: model.modelW+17.0, height: model.modelH+10.0)
            } else {
                self.nickLabel.isHidden = true
                //聊天气泡
                self.bubbleImageView.frame = CGRect.init(x: self.avatarImageView.chat_minX-model.modelW-22.0, y: self.avatarImageView.chat_minY, width: model.modelW+17.0, height: model.modelH+10)
            }
            self.bubbleImageView.image = ADSChatHelper.senderBubble()
            
            //消息内容
            var rect: CGRect = self.bubbleImageView.frame
            if model.msgType == ADSMessageType.ADSMessageTypeText {
                rect.origin.x += 5
                rect.size.width -= 17
            }
            self.contentRect = rect
            
            //正在发送菊花动画
            self.activityView.frame = CGRect.init(x: self.bubbleImageView.chat_minX-40.0, y: self.bubbleImageView.chat_minY+(self.bubbleImageView.chat_height-40.0)/2, width: 40, height: 40)
            
            if model.sendType == ADSMessageSendType.WZMMessageSendTypeWaiting {
                self.activityView.isHidden = false
                self.activityView.startAnimating()
                
                self.retryBtn.isHidden = true
            } else if model.sendType == ADSMessageSendType.WZMMessageSendTypeSuccess {
                self.activityView.isHidden = true
                self.activityView.stopAnimating()
                
                self.retryBtn.isHidden = true
            } else {
                self.activityView.isHidden = true
                self.activityView.stopAnimating()
                
                self.retryBtn.isHidden = false
            }
            
            //发送失败感叹号
            self.retryBtn.frame = CGRect.init(x: self.activityView.chat_minX, y: self.bubbleImageView.chat_maxY-30.0, width: 40.0, height: 40.0)
        }
        else {
            self.avatarImageView.frame = CGRect.init(x: 10, y: 10, width: 40, height: 40)
            //可改成网络图片
            let _ = ADSChatHelper.sharedHelper.getImageWithUrl(urlString: model.avatar, isUseCatch: true) { image in
                self.avatarImageView.image = image
            }
            
            self.nickLabel.frame = CGRect.init(x: self.avatarImageView.chat_maxX+10, y: 5, width: 400, height: 20)
            self.nickLabel.text = model.name
            self.nickLabel.textAlignment = NSTextAlignment.left
            
            if isShowName {
                self.nickLabel.isHidden = false
                //聊天气泡
                self.bubbleImageView.frame = CGRect.init(x: self.avatarImageView.chat_maxX+5, y: self.nickLabel.chat_maxY, width: model.modelW+17, height: model.modelH+10)
            }
            else {
                self.nickLabel.isHidden = true
                //聊天气泡
                self.bubbleImageView.frame = CGRect.init(x: self.avatarImageView.chat_maxX+5, y: self.avatarImageView.chat_minY, width: model.modelW+17, height: model.modelH+10)
            }
            self.bubbleImageView.image = ADSChatHelper.sharedHelper.receiverBubbleImage
            
            var rect: CGRect = self.bubbleImageView.frame
            if model.msgType == ADSMessageType.ADSMessageTypeText {
                rect.origin.x += 12
                rect.size.width -= 17
            }
            self.contentRect = rect
            
            self.activityView.isHidden = true
            self.activityView.stopAnimating()
            self.activityView.frame = CGRect.init(x: self.bubbleImageView.chat_maxX, y: self.bubbleImageView.chat_minY+(self.bubbleImageView.chat_height-40)/2, width: 40, height: 40)
            
            //发送失败感叹号
            self.retryBtn.isHidden = true
            self.retryBtn.frame = CGRect.init(x: self.activityView.chat_minX, y: self.bubbleImageView.chat_maxY-30.0, width: 40.0, height: 40.0)
        }
    }

}
