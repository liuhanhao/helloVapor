//
//  WZMChatBaseCell.swift
//  VaporChat
//
//  Created by admin on 2022/11/1.
//

import UIKit

class WZMChatBaseCell: UITableViewCell {

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = UIColor.clear
        self.selectionStyle = UITableViewCell.SelectionStyle.none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    ///系统消息 - 比如：时间消息等
    func setConfig(model: ADSChatMessageModel) {
        
    }

    ///其他消息 - 比如：文本、图片消息等
    func setConfig(model: ADSChatMessageModel, isShowName: Bool) {
        
    }

}
