//
//  ADSChatVideoMessageCell.swift
//  VaporChat
//
//  Created by admin on 2022/11/1.
//

import Foundation
import UIKit

class ADSChatVideoMessageCell: ADSChatMessageCell {

    var markImageView = UIImageView.init()
    var contentImageView = UIImageView.init()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(self.markImageView)
        self.contentView.addSubview(self.contentImageView)
        
        self.contentImageView.layer.masksToBounds = true
        self.contentImageView.layer.cornerRadius = 5.0
        
        self.markImageView.image = ADSInputHelper.otherImageNamed(name: "wzm_chat_video_mark")
        
    }
    
    override func setConfig(model: ADSChatMessageModel, isShowName: Bool) {
        super.setConfig(model: model, isShowName: isShowName)
        
        self.contentImageView.frame = self.contentRect
        self.markImageView.center = self.contentImageView.center
        let _ = ADSChatHelper.sharedHelper.getImageWithUrl(urlString: model.coverUrl, isUseCatch: true) { image in
            self.contentImageView.image = image
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
