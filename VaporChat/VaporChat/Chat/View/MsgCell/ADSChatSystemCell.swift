//
//  ADSChatSystemCell.swift
//  VaporChat
//
//  Created by admin on 2022/11/1.
//

import Foundation
import UIKit

class ADSChatSystemCell: ADSChatBaseCell {

    var messageLabel: UILabel = UILabel.init()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.messageLabel.frame = CGRect.init(x: 0, y: 0, width: self.CHAT_SCREEN_WIDTH(), height: 20)
        self.messageLabel.font = UIFont.systemFont(ofSize: 10)
        self.messageLabel.textColor = UIColor.init(ts_red: 100, green: 100, blue: 100)
        self.messageLabel.textAlignment = NSTextAlignment.center
        self.contentView.addSubview(self.messageLabel)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setConfig(model: ADSChatMessageModel) {
        self.messageLabel.text = model.message
    }

}
