//
//  ADSChatVoiceMessageCell.swift
//  VaporChat
//
//  Created by admin on 2022/11/1.
//

import Foundation
import UIKit

class ADSChatVoiceMessageCell: ADSChatMessageCell {

    var durationLabel: UILabel = UILabel.init()
    var voiceImageView: UIImageView = UIImageView.init()
    var unreadImageView: UIImageView = UIImageView.init()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(self.durationLabel)
        self.contentView.addSubview(self.voiceImageView)
        self.contentView.addSubview(self.unreadImageView)
        
        self.durationLabel.textColor = UIColor.darkText
        self.durationLabel.font = UIFont.systemFont(ofSize: 15)

        self.unreadImageView.backgroundColor = UIColor.init(ts_red: 250, green: 81, blue: 81)
        self.unreadImageView.chat_cornerRadius = 4.0
        
    }
    
    override func setConfig(model: ADSChatMessageModel, isShowName: Bool) {
        super.setConfig(model: model, isShowName: isShowName)
        
        let x = self.contentRect.origin.x
        let y = self.contentRect.origin.y
        let w = self.contentRect.size.width
        let h = self.contentRect.size.height
        
        let imageW = 12.0
        let imageH = 15.0
        let imageY = y + (h - imageH) / 2
        if model.sender {
            self.voiceImageView.frame = CGRect.init(x: self.contentRect.maxX - 20 - imageW, y: imageY, width: imageW, height: imageH)
            self.voiceImageView.image = ADSInputHelper.otherImageNamed(name: "wzm_chat_voice_2")
            self.durationLabel.frame = CGRect.init(x: x, y: y, width: w - self.voiceImageView.chat_width - 25, height: h)
            self.durationLabel.textAlignment = NSTextAlignment.right
            self.unreadImageView.frame = CGRect.init(x: x - 10.0, y: y, width: 8, height: 8)
            self.unreadImageView.isHidden = true
        } else {
            self.voiceImageView.frame = CGRect.init(x: self.contentRect.minX + 20, y: imageY, width: imageW, height: imageH)
            self.voiceImageView.image = ADSInputHelper.otherImageNamed(name: "wzm_chat_voice_1")
            self.durationLabel.frame = CGRect.init(x: self.voiceImageView.chat_maxX + 5, y: y, width: w - self.voiceImageView.chat_width - 25, height: h)
            self.durationLabel.textAlignment = NSTextAlignment.left
            self.unreadImageView.frame = CGRect.init(x: self.contentRect.maxX + 2, y: y, width: 8, height: 8)
            self.unreadImageView.isHidden = model.read
        }
        
        self.durationLabel.text = String((model.duration)) + "''"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
