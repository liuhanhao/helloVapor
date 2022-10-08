//
//  ADSDeleteCell.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/25.
//

import UIKit

class ADSDeleteCell: UICollectionViewCell {
    fileprivate var deleteImgView: UIImageView
    
    override init(frame: CGRect) {
        self.deleteImgView = UIImageView.init(frame: CGRect.init(x: 6, y: 5, width: 40, height: 40))
        self.deleteImgView.image = ADSInputHelper.otherImageNamed(name: "wzm_chat_delete")

        super.init(frame: frame)
        
        self.contentView.addSubview(self.deleteImgView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
