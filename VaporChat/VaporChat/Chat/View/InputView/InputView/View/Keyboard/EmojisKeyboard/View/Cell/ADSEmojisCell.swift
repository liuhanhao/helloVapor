//
//  ADSEmojisCell.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/25.
//

import UIKit

class ADSEmojisCell: UICollectionViewCell {
    fileprivate var emojisLabel: UILabel
    
    override init(frame: CGRect) {
        self.emojisLabel = UILabel.init(frame: CGRect.init(x: 4, y: 0, width: 45, height: 45))
        self.emojisLabel.font = UIFont.systemFont(ofSize: 33)
        self.emojisLabel.textAlignment = NSTextAlignment.center
        
        super.init(frame: frame)
        
        self.contentView.addSubview(self.emojisLabel)
    }
    
    func setConfig(emojis: String) {
        self.emojisLabel.text = emojis
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
