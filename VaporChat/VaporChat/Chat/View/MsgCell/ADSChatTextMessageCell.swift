//
//  ADSChatTextMessageCell.swift
//  VaporChat
//
//  Created by admin on 2022/11/1.
//

import Foundation
import UIKit

class ADSChatTextMessageCell: ADSChatMessageCell {

    var contentLabel: UILabel = UILabel.init()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentLabel.textColor = UIColor.darkText
        self.contentLabel.numberOfLines = 0
        self.contentView.addSubview(self.contentLabel)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setConfig(model: ADSChatMessageModel, isShowName: Bool) {
        super.setConfig(model: model, isShowName: isShowName)
        self.contentLabel.attributedText = model.attStr
        self.contentLabel.frame = self.contentRect
        if model.modelW > 30 {
            self.contentLabel.textAlignment = NSTextAlignment.left
        } else {
            self.contentLabel.textAlignment = NSTextAlignment.center
        }
    }

}
