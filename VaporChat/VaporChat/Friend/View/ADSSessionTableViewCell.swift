//
//  ADSSessionTableViewCell.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class ADSSessionTableViewCell: UITableViewCell {

    var _avatarImageView: UIImageView = UIImageView.init()
    var _badgeView: UIView = UIView.init()
    var _badgeLabel: UILabel = UILabel.init()
    var _nameLabel: UILabel = UILabel.init()
    var _messageLabel: UILabel = UILabel.init()
    var _timeLabel: UILabel = UILabel.init()
    var _notiImageView: UIImageView = UIImageView.init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        _avatarImageView.frame = CGRect.init(x: 15, y: 11, width: 48, height: 48)
        _avatarImageView.chat_cornerRadius = 5
        self.contentView.addSubview(_avatarImageView)
        
        _badgeView.frame = CGRect.init(x: _avatarImageView.chat_maxX-5, y: _avatarImageView.chat_minY-5, width: 10, height: 10)
        _badgeView.backgroundColor = UIColor.init(ts_red: 250, green: 81, blue: 81)
        _badgeView.chat_cornerRadius = 5
        _badgeView.isHidden = true
        self.contentView.addSubview(_badgeView)
        
        _badgeLabel.frame = CGRect.init(x: _avatarImageView.chat_maxX-9, y: _avatarImageView.chat_minY-9, width: 18, height: 18)
        _badgeLabel.font = UIFont.systemFont(ofSize: 12)
        _badgeLabel.textColor = UIColor.white
        _badgeLabel.textAlignment = NSTextAlignment.center
        _badgeLabel.backgroundColor = UIColor.init(ts_red: 250, green: 81, blue: 81)
        _badgeLabel.chat_cornerRadius = 9
        _badgeLabel.isHidden = true
        self.contentView.addSubview(_badgeLabel)
        
        let timeW: CGFloat = 100.0
        let nickX: CGFloat = _avatarImageView.chat_maxX+15
        let nimeW: CGFloat = self.CHAT_SCREEN_WIDTH()-nickX-timeW-15
        
        _nameLabel.frame = CGRect.init(x: nickX, y: 13, width: nimeW, height: 20)
        _nameLabel.font = UIFont.systemFont(ofSize: 16)
        _nameLabel.textColor = UIColor.darkGray
        _nameLabel.textAlignment = NSTextAlignment.left
        self.contentView.addSubview(_nameLabel)
        
        _messageLabel.frame = CGRect.init(x: nickX, y: _nameLabel.chat_maxY+7, width: nimeW+60, height: 15)
        _messageLabel.font = UIFont.systemFont(ofSize: 13)
        _messageLabel.textColor = UIColor.init(ts_red: 160, green: 160, blue: 160)
        _messageLabel.textAlignment = NSTextAlignment.left
        self.contentView.addSubview(_messageLabel)
        
        _timeLabel.frame = CGRect.init(x: _nameLabel.chat_maxX, y: 15, width: timeW, height: 15)
        _timeLabel.font = UIFont.systemFont(ofSize: 12)
        _timeLabel.textColor = UIColor.gray
        _timeLabel.textAlignment = NSTextAlignment.right
        self.contentView.addSubview(_timeLabel)
        
        _notiImageView.frame = CGRect.init(x: self.CHAT_SCREEN_WIDTH()-32, y: _avatarImageView.chat_maxY-20, width: 17, height: 17)
        _notiImageView.isHidden = true
        _notiImageView.image = ADSInputHelper.otherImageNamed(name: "wzm_chat_bell_not")
        self.contentView.addSubview(_notiImageView)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setConfig(model: ADSChatSessionModel) {
        var isIgnore: Bool = model.silence
        var lastTimestamp = model.lastTimestmp
        var lastMsg = model.lastMsg
        
        var unreadNum = 0
        if let num = Int(model.unreadNum) {
            unreadNum = num
        }
        
        if isIgnore {
            //消息免打扰
            _notiImageView.isHidden = false
            _badgeLabel.text = ""
            _badgeLabel.isHidden = true
            if unreadNum > 0 {
                _badgeView.isHidden = false
                if unreadNum > 1 {
                    lastMsg = "[" + String(unreadNum) + "条] " + lastMsg
                }
            }
            else {
                _badgeView.isHidden = true
            }
        }
        else {
            //消息提醒
            _notiImageView.isHidden = true
            if unreadNum <= 0 {
                _badgeLabel.text = ""
                _badgeView.isHidden = true
                _badgeLabel.isHidden = true
            }
            else {
                _badgeLabel.text = String(unreadNum)
                _badgeView.isHidden = true
                _badgeLabel.isHidden = false
                if unreadNum < 10 {
                    _badgeLabel.frame = CGRect.init(x: _avatarImageView.chat_maxX-9, y: _avatarImageView.chat_minY-9, width: 18, height: 18)
                }
                else if unreadNum < 100 {
                    _badgeLabel.frame = CGRect.init(x: _avatarImageView.chat_maxX-17, y: _avatarImageView.chat_minY-9, width: 26, height: 18)
                }
                else {
                    _badgeLabel.text = "···"
                    _badgeLabel.frame = CGRect.init(x: _avatarImageView.chat_maxX-21, y: _avatarImageView.chat_minY-9, width: 30, height: 18)
                }
            }
        }
        let _ = ADSChatHelper.sharedHelper.getImageWithUrl(urlString: model.avatar, isUseCatch: true) { image in
            self._avatarImageView.image = image
        }
        _nameLabel.text = model.name
        _messageLabel.text = lastMsg
        _timeLabel.text = ADSChatHelper.timeFromTimeStamp(timeStamp: String(lastTimestamp))
        
        if _notiImageView.isHidden {
            _messageLabel.chat_width = _nameLabel.chat_width+100
        }
        else {
            _messageLabel.chat_width = _nameLabel.chat_width+80
        }
    }

}
