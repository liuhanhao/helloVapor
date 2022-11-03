//
//  WZMChatImageMessageCell.swift
//  VaporChat
//
//  Created by admin on 2022/11/1.
//

import Foundation
import UIKit

class WZMChatImageMessageCell: WZMChatMessageCell {

    var contentImageView: UIImageView = UIImageView.init()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentImageView.layer.masksToBounds = true
        self.contentImageView.layer.cornerRadius = 5.0
        self.contentView.addSubview(self.contentImageView)
        
    }
    
    override func setConfig(model: ADSChatMessageModel, isShowName: Bool) {
        super.setConfig(model: model, isShowName: isShowName)
        
        self.contentImageView.frame = self.contentRect
        let _ = ADSChatHelper.sharedHelper.getImageWithUrl(urlString: model.thumbnail, isUseCatch: true) { image in
            self.avatarImageView.image = image
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
