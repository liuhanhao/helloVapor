//
//  ADSEmoticonCell.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/25.
//

import UIKit

class ADSEmoticonCell: UICollectionViewCell {
    fileprivate var emoticonImageView: UIImageView
    
    override init(frame: CGRect) {
        self.emoticonImageView = UIImageView.init(frame: CGRect.init(x: 9, y: 6, width: 35, height: 35))
        
        super.init(frame: frame)
        self.contentView.addSubview(self.emoticonImageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setConfig(image: String) {
        self.emoticonImageView.image = ADSInputHelper.emoticonImageNamed(name: image)
    }
    
}
