//
//  WZMUserTableViewCell.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class WZMUserTableViewCell: UITableViewCell {

    var _avatarImageView: UIImageView = UIImageView.init()
    var _nameLabel: UILabel = UILabel.init()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        _avatarImageView.frame = CGRect.init(x: 15, y: 10, width: 40, height: 40)
        _avatarImageView.chat_cornerRadius = 5
        self.contentView.addSubview(_avatarImageView)
        
        let nickX: CGFloat = _avatarImageView.chat_maxX+15
        let nickW: CGFloat = self.CHAT_SCREEN_WIDTH()-nickX-20
        
        _nameLabel.frame = CGRect.init(x: nickX, y: 0, width: nickW, height: 60)
        _nameLabel.font = UIFont.systemFont(ofSize: 16)
        _nameLabel.textColor = UIColor.darkText
        _nameLabel.textAlignment = NSTextAlignment.left
        self.contentView.addSubview(_nameLabel)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setConfig(model: ADSChatUserModel) {
        let _ = ADSChatHelper.sharedHelper.getImageWithUrl(urlString: model.avatar, isUseCatch: true) { image in
            self._avatarImageView.image = image
        }
        
        _nameLabel.text = model.name;
    }
}
