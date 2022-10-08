//
//  ADSHorizontalLayout.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/25.
//

import UIKit

class ADSHorizontalLayout: UICollectionViewLayout {
    
    // 获取当前设置下的itemSize
    var WZMItemSize: CGSize
    fileprivate var attributesArray: [UICollectionViewLayoutAttributes] = []
    fileprivate var contentSizeWidth: CGFloat = 0.0
    fileprivate var keyboardW: CGFloat = 0.0
    
    fileprivate var spacing: CGFloat
    fileprivate var nums: Int
    fileprivate var rows: Int
    fileprivate var items: Int
    
    /**
     *  初始化
     *
     *  @param spacing 每个item之间的距离
     *  @param rows    每页显示的item行数
     *  @param nums    每行显示的item个数
     *
     *  @return layout
     */
    init(spacing: CGFloat, rows: Int, nums: Int) {
        self.spacing = spacing
        self.rows = rows
        self.nums = nums
        self.items = nums * rows
        self.keyboardW = UIScreen.main.bounds.size.width
        let itemWidth = (self.keyboardW - CGFloat((self.nums + 1)) * self.spacing) / CGFloat(self.nums)
        let itemHeigh = itemWidth * 0.9
        
        self.WZMItemSize = CGSize.init(width: itemWidth, height: itemHeigh)
        
        super.init()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepare() {
        self.contentSizeWidth = 0.0
        self.attributesArray = []
        let itemWidth = self.WZMItemSize.width
        let itemHeight = self.WZMItemSize.height
        
        let sections = self.collectionView!.numberOfSections
        for section in 0..<sections {
            let items = self.collectionView!.numberOfItems(inSection: section)
            
            for item in 0..<items {
                let indexPath = IndexPath.init(item: item, section: section)
                var frame = CGRect.zero
                frame.origin.x = self.spacing + CGFloat(Float(item % self.nums)) * (self.spacing + itemWidth) + CGFloat((item / self.items)) * self.keyboardW + self.contentSizeWidth;
                frame.origin.y = self.spacing + CGFloat(item / self.nums % self.rows) * (self.spacing + itemHeight);
                frame.size.width = itemWidth;
                frame.size.height = itemHeight;
                
                let attributes = UICollectionViewLayoutAttributes.init(forCellWith: indexPath)
                attributes.frame = frame
                self.attributesArray.append(attributes)
            }
        }
        
    }
    
    func collectionViewContentSize() -> CGSize {
        var size = CGSize.zero
        size.height = self.collectionView!.frame.size.height
        size.width = self.contentSizeWidth
        return size
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var resultArray: [UICollectionViewLayoutAttributes] = []
        for i in 0..<self.attributesArray.count {
            let attributes = self.attributesArray[i]
            if rect.intersects(attributes.frame) {
                resultArray.append(attributes)
            }
        }
        
        return resultArray
    }
    
}
