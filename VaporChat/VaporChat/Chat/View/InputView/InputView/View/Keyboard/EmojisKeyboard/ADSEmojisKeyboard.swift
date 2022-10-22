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
        return self.totalCount(count: emoticons.count)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if self.isDelete(index: indexPath.item) {
            let cell: ADSDeleteCell = collectionView.dequeueReusableCell(withReuseIdentifier: "delete", for: indexPath) as! ADSDeleteCell
            return cell
        } else {
            let emojis = emoticons[indexPath.section]
            let index = self.trueIndex(index: indexPath.item)
            if index < emojis.count {
                if indexPath.section == self.emojisSection {
                    //emojis表情
                    let text = emojis[index]["key"]
                    let cell: ADSEmojisCell = collectionView.dequeueReusableCell(withReuseIdentifier: "emojis", for: indexPath) as! ADSEmojisCell
                    cell.setConfig(emojis: text)
                    return cell
                } else {
                    //图片表情
                    let dic = emojis[index]
                    let cell: ADSEmoticonCell = collectionView.dequeueReusableCell(withReuseIdentifier: "emoticon", for: indexPath) as! ADSEmoticonCell
                    cell.setConfig(image: dic["png"])
                    return cell
                }
            }
            else {
                let cell: ADSBlankCell = collectionView.dequeueReusableCell(withReuseIdentifier: "blank", for: indexPath) as! ADSBlankCell
                return cell
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if self.isDelete(index: indexPath.item) {
            self.delegate?.emojisKeyboardDidSelectDelete(emojisKeyboard: self)
        } else {
            let text = self.textWithIndexPath(indexPath: indexPath)
            self.delegate?.emojisKeyboard(emojisKeyboard: self, didSelectText: text)
            
        }
    }
    
    @objc func toolBtnClick(btn: UIButton) {
        guard !btn.isSelected else {
            return
        }
        self.selectedBtn(btn: btn)
        let index = self.totalPageBeforeSection(section: btn.tag)
        self.collectionView?.setContentOffset(CGPoint.init(x: ADSInputHelper.sharedHelper.screenW() * CGFloat(index), y: 0), animated: false)
    }

    @objc func sendBtnClick(btn: UIButton) {
        self.delegate?.emojisKeyboardDidSelectSend(emojisKeyboard: self)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let index = scrollView.contentOffset.x / ADSInputHelper.sharedHelper.screenW()
        let section = self.currectSection(index: Int(index))
        let btn = btns[section]
        if btn.isSelected {
            return
        }
        self.selectedBtn(btn: btn)
    }

    
    
    func selectedBtn(btn: UIButton) {
        self.selectedBtn?.isSelected = false
        self.selectedBtn = btn
        self.selectedBtn?.isSelected = true
    }

    func textWithIndexPath(indexPath: IndexPath) -> String {
        if indexPath.section < emoticons.count {
            if indexPath.section == emojisSection {
                //emojis表情
                let emojis = emoticons[indexPath.section]
                let index = self.trueIndex(index: indexPath.item)
                if index < emojis.count {
                    if let a = emojis[index]["key"] {
                        return a
                    }
                }
            } else {
                //图片表情
                let emojis = emoticons[indexPath.section]
                let index = self.trueIndex(index: indexPath.item)
                if index < emojis.count {
                    if let a = emojis[index]["chs"] {
                        return a
                    }
                }
            }
        }
        return ""
    }
    
    //是否是删除键
    func isDelete(index: Int) -> Bool {
        let c = Emojis_Key_Rows * Emojis_Key_Nums
        return ((index + 1) % c) == 0
    }

    //数组中的正确索引
    func trueIndex(index: Int) -> Int {
        let c = Emojis_Key_Rows * Emojis_Key_Nums
        //已经加了的删除键个数
        let count = (index+1)/c
        return index - count
    }

    //区item总个数
    func totalCount(count : Int) -> Int {
        let c = Emojis_Key_Rows * Emojis_Key_Nums
        //一共需要的删除键个数
        let dc = ceil(CGFloat(count) * 1.0 / CGFloat(c-1))
        return Int(dc * CGFloat(c))
    }
    
    //区总页数
    func totalPage(count : Int) -> Int {
        let c = Emojis_Key_Rows * Emojis_Key_Nums
        return Int(ceil(CGFloat(count) * 1.0 / CGFloat(c-1)))
    }

    //获取当前区数
    func currectSection(index: Int) -> Int {
        var lastPage = 0
        for i in 0..<emoticons.count {
            let emojis = emoticons[i]
            if i == emojisSection {
                lastPage = self.totalPage(count: emojis.count) + lastPage
            } else {
                //图片表情
                lastPage = self.totalPage(count: emojis.count) + lastPage
            }
            if index < lastPage {
                return i
            }
        }
        return 0
    }

    //获取在当前区中的页数
    func currectPage(index: Int) -> Int {
        let page = self.currectSection(index: index)
        var lastPage = 0
        for i in 0..<page {
            let emojis = emoticons[i]
            if i == emojisSection {
                lastPage = self.totalPage(count: emojis.count) + lastPage
            } else {
                //图片表情
                lastPage = self.totalPage(count: emojis.count) + lastPage
            }
        }
        return index-lastPage
    }
    
    //指定区之前有多少页数
    func totalPageBeforeSection(section: Int) -> Int {
        var lastPage = 0
        for i in 0..<section {
            let emojis = emoticons[i]
            if i == emojisSection {
                lastPage = self.totalPage(count: emojis.count) + lastPage
            } else {
                //图片表情
                lastPage = self.totalPage(count: emojis.count) + lastPage
            }
        }
        return lastPage
    }
    
}
