//
//  ADSEmojisKeyboard.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/25.
//

import UIKit

protocol ADSEmojisKeyboardDelegate: NSObjectProtocol {
    func emojisKeyboardDidSelectSend(emojisKeyboard: ADSEmojisKeyboard)
    func emojisKeyboardDidSelectDelete(emojisKeyboard: ADSEmojisKeyboard)
    func emojisKeyboard(emojisKeyboard: ADSEmojisKeyboard, didSelectText text: String)
}

let Emojis_Key_Rows: Int = 3
let Emojis_Key_Nums: Int = 7

class ADSEmojisKeyboard: UIView, UICollectionViewDelegate, UICollectionViewDataSource {
    
    weak open var delegate: ADSEmojisKeyboardDelegate?
    
    fileprivate var btns: [UIButton] = []
    fileprivate var emoticons: [[[String:String]]] = [[[:]]]
    fileprivate var selectedBtn: UIButton?
    fileprivate var emojisSection: Int = 0
    fileprivate var collectionView: UICollectionView?
    
    override init(frame: CGRect) {
        self.emoticons = ADSEmoticonManager.manager().emoticons
        self.emojisSection = self.emoticons.count - 1
        
        let key_itemW: CGFloat = 45
        let spcing: CGFloat = (320.0 - key_itemW * CGFloat(Emojis_Key_Nums)) / CGFloat((Emojis_Key_Nums + 1))
        let horLayout:ADSHorizontalLayout = ADSHorizontalLayout.init(spacing: spcing, rows: Emojis_Key_Rows, nums: Emojis_Key_Nums)
        
        super.init(frame: frame)
        
        var rect = self.bounds
        rect.size.height = rect.size.height - (40 + ADSInputHelper.sharedHelper.iPhoneXBottomH())
        self.collectionView = UICollectionView.init(frame: rect, collectionViewLayout: horLayout)
        self.collectionView?.delegate = self
        self.collectionView?.dataSource = self
        self.collectionView?.backgroundColor = UIColor.clear
        if #available(iOS 11.0, *) {
            self.collectionView?.contentInsetAdjustmentBehavior = .never
        }
        self.collectionView?.isPagingEnabled = true
        self.collectionView?.register(ADSBlankCell.self, forCellWithReuseIdentifier: "blank")
        self.collectionView?.register(ADSEmojisCell.self, forCellWithReuseIdentifier: "emojis")
        self.collectionView?.register(ADSDeleteCell.self, forCellWithReuseIdentifier: "delete")
        self.collectionView?.register(ADSEmoticonCell.self, forCellWithReuseIdentifier: "emoticon")
        self.addSubview(self.collectionView!)
        
        let themeColor = UIColor.init(ts_red: 34, green: 207, blue: 172)
        let toolView = UIView.init(frame: CGRect.init(x: 0, y: self.collectionView!.frame.maxY, width: frame.size.width, height: 40 + ADSInputHelper.sharedHelper.iPhoneXBottomH()))
        toolView.backgroundColor = UIColor.init(ts_red: 220, green: 220, blue: 220)
        self.addSubview(toolView)
        
        var btns: [UIButton] = []
        let names = ["默认","浪小花","emojis"]
        for i in 0..<names.count {
            let btn = UIButton.init(type: .custom)
            btn.tag = i
            btn.frame = CGRect.init(x: i * 60, y: 0, width: 60, height: 40)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            btn.setTitle(names[i], for: UIControl.State.normal)
            btn.setTitleColor(themeColor, for: UIControl.State.normal)
            btn.addTarget(self, action: #selector(Self.toolBtnClick(btn:)), for: UIControl.Event.touchUpInside)
            toolView.addSubview(btn)
            
            btns.append(btn)
            if i == 0 {
                self.selectedBtn = btn
                self.selectedBtn?.isSelected = true
            }
        }
        
        self.btns = btns
        
        let sendBtn = UIButton.init(type: UIButton.ButtonType.custom)
        sendBtn.frame = CGRect.init(x: frame.size.width - 80, y: 0, width: 80, height: 40)
        sendBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        sendBtn.backgroundColor = themeColor
        sendBtn.setTitle("发送", for: UIControl.State.normal)
        sendBtn.addTarget(self, action:#selector(Self.sendBtnClick(btn:)), for: UIControl.Event.touchUpInside)
        toolView.addSubview(sendBtn)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
   
    
    /// UICollectionViewDataSource,UICollectionViewDelegate
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.emoticons.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let emoticons = self.emoticons[section]
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        <#code#>
    }
    
    @objc func toolBtnClick(btn: UIButton) {
        guard !btn.isSelected else {
            return
        }
        
    }
    
    func <#name#>(<#parameters#>) -> <#return type#> {
        <#function body#>
    }
    
    @objc func sendBtnClick(btn: UIButton) {
        
    }
    
}
