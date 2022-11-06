//
//  ADSChatViewController.swift
//  VaporChat
//
//  Created by admin on 2022/10/31.
//

import UIKit

let WZM_LOADING_HEADER = 50.0

// ,UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate
class ADSChatViewController: ADSBaseViewController,UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate,WZMInputViewDelegate {
    
    ///列表相关
    var tableViewY: CGFloat = NSObject.init().CHAT_NAV_BAR_H()
    var messageModels: [ADSChatMessageModel] = []
    lazy var tableView: UITableView = {
        var rect = self.view.bounds
        rect.origin.y = self.tableViewY
        rect.size.height = rect.size.height - (self.tableViewY + self.myInputView.toolViewH)
        
        let tableView = UITableView.init(frame: rect, style: UITableView.Style.plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInsetAdjustmentBehavior = UIScrollView.ContentInsetAdjustmentBehavior.never
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.tableFooterView = UIView.init()
        tableView.backgroundColor = UIColor.init(ts_red: 240, green: 240, blue: 240)
        tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        
        return tableView
    }()

    ///当前私聊用户
    var userModel: ADSChatUserModel?
    ///当前群聊
    var groupModel: ADSChatGroupModel?
    ///私聊消息是否显示昵称, 不需要手动设置, 会根据私聊或者群聊用户自动判断, 此处只做记录
    var showName: Bool = false
    
    ///自定义表情键盘
    lazy var myInputView: ADSInputView = {
        let _myInputView = ADSInputView.init()
        _myInputView.delegate = self
        if let userModel = self.userModel {
            _myInputView.text = ADSChatDBManager.shared.draft(model: userModel)
        } else if let groupModel = self.groupModel {
            _myInputView.text = ADSChatDBManager.shared.draft(model: groupModel)
        }
        
        return _myInputView
    }()
    ///手势处理相关
    weak var recognizerDelegate: UIGestureRecognizerDelegate?
    
    var deferredSystemGestures: Bool = false
    ///下拉加载
    var page: Int = 0
    //此次加载的消息数量,为了计算加载后消息列表的偏移量
    var loadCount: Int = 0
    var loading: Bool = false
    lazy var loadingView: UIActivityIndicatorView = {
        let _loadingView = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.gray)
        _loadingView.frame = CGRect.init(x: 0, y: -WZM_LOADING_HEADER, width: self.CHAT_SCREEN_WIDTH(), height: WZM_LOADING_HEADER)
        _loadingView.hidesWhenStopped = true
        
        return _loadingView
    }()
    
    ///选择用户进入聊天
    convenience init(userModel: ADSChatUserModel) {
        self.init()
    }
    
    ///选择群进入聊天
    convenience init(groupModel: ADSChatGroupModel) {
        self.init()
    }
        
    ///选择会话进入聊天
    convenience init(sessionModel: ADSChatSessionModel) {
        self.init()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateRecognizerDelegate(appear: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.updateRecognizerDelegate(appear: false)
        self.deferredSystemGestures = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //UI布局
        self.createViews()
        //屏蔽系统底部手势
        self.deferredSystemGestures = true
        //加载聊天记录
        self.loadMessage(page: 0)
        //模拟发送消息
        self.setRightItem()
    }
    
    func createViews() {
        self.view.addSubview(self.tableView)
        self.view.addSubview(self.myInputView)
        self.tableView.addSubview(self.loadingView)
    }
    
    /// 模拟收到消息
    func setRightItem() {
        let item = UIBarButtonItem.init(title: "模拟收到消息", style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.rightItemClick))
        self.navigationItem.rightBarButtonItem = item
    }
    
    @objc func rightItemClick() {
        if Self.msgType == ADSMessageType.ADSMessageTypeSystem.rawValue {
            let timeMessage = ADSChatHelper.timeFromDate(date: Date.init())
            
            let model = ADSChatMessageManager.createSystemMessage(userModel: self.userModel!, message: timeMessage, isSender: true)
            self.receiveMessageModel(message: model)
        } else if Self.msgType == ADSMessageType.ADSMessageTypeText.rawValue {
            let timeMessage = ADSChatHelper.timeFromDate(date: Date.init())
            
            let model = ADSChatMessageManager.createTextMessage(userModel: self.userModel!, message: "[微笑]我收到了一条文本消息", isSender: false)
            self.receiveMessageModel(message: model)
        } else if Self.msgType == ADSMessageType.ADSMessageTypeImage.rawValue {
            //收到图片
            //原图和缩略图链接
            let original = "http://www.vasueyun.cn/llgit/WZMChat/2.jpg"
            let thumbnail = "http://www.vasueyun.cn/llgit/WZMChat/2_t.jpg"
            //图片下载的代码就不多写, 这里默认下载完成
            //原图
            let oriImage = UIImage.init(named: "2.jpg")
            //缩略图, 消息展示, 优化消息滑动时的卡顿
            let thumImage = UIImage.init(named: "2_t.jpg")
            
            let model = ADSChatMessageManager.createImageMessage(userModel: self.userModel!, thumbnail: thumbnail, original: original, thumImage: thumImage ?? UIImage(), oriImage: oriImage ?? UIImage(), isSender: false)
            self.receiveMessageModel(message: model)
        } else if Self.msgType == ADSMessageType.ADSMessageTypeVoice.rawValue {
            //接收到声音
            //声音地址
            let voiceUrl = ""
            let duration = arc4random() % 60 + 1
            
            let model = ADSChatMessageManager.createVoiceMessage(userModel: self.userModel!, duration: Double(duration), voiceUrl: voiceUrl, isSender: false)
            self.receiveMessageModel(message: model)
        } else if Self.msgType == ADSMessageType.ADSMessageTypeVideo.rawValue {
            //收到视频
            let videoUrl = ""
            //封面图链接
            let coverUrl = "http://www.vasueyun.cn/llgit/WZMChat/1_t.jpg"
            //下载封面图
            let coverImage = UIImage.init(named: "1_t.jpg")
            //创建视频model
            let model = ADSChatMessageManager.createVideoMessage(userModel: self.userModel!, videoUrl: videoUrl, coverUrl: coverUrl, coverImage: coverImage ?? UIImage(), isSender: false)
            self.receiveMessageModel(message: model)
        }
        
        Self.msgType = (Self.msgType+1)%5
    }

    //发送消息
    ///文本变化
    func inputView(_: ADSInputView, didChangeText text: String) {
        //保存草稿
        ADSChatDBManager.shared.setDraft(model: self.userModel!, draft: text)
    }
    ///发送文本消息
    func inputView(_: ADSInputView, sendMessage message: String) {
        //清空草稿
        ADSChatDBManager.shared.removeDraft(model: self.userModel!)
        
        let model: ADSChatMessageModel = ADSChatMessageManager.createTextMessage(userModel: self.userModel!, message: message, isSender: true)
        self.sendMessageModel(message: model)
    }
    //录音状态变化
    func inputView(_: ADSInputView, didChangeRecordType recordType: Int) {
        if recordType == ADSRecordType.ADSRecordTypeBegin.rawValue {
            //开始录音
            Self.start = ADSChatHelper.nowTimestamp()
        } else if recordType == ADSRecordType.ADSRecordTypeFinish.rawValue {
            let duration = ADSChatHelper.nowTimestamp() - Self.start
            //结束录音
            //将录音上传到服务器, 获取录音链接
            let voiceUrl = ""
            //创建录音model
            let model: ADSChatMessageModel = ADSChatMessageManager.createVoiceMessage(userModel: self.userModel!, duration: duration/1000, voiceUrl: voiceUrl, isSender: true)
            self.sendMessageModel(message: model)
        } else {
            
        }
    }
    //键盘状态变化
    func inputView(_: ADSInputView, willChangeFrameWithDuration duration: CGFloat) {
        self.tableViewScrollToBottom(animated: true, duration: duration)
    }
    //其他自定义消息, 如: 图片、视频、位置等等
    func inputView(_: ADSInputView, didSelectMoreType inputMoreType: Int) {
        if inputMoreType == ADSInputMoreType.ADSInputMoreTypeImage.rawValue {
            //发送图片
            //选择图片的代码就不多写了, 这里假定已经选择了图片
            
            //原图,
            let oriImage = UIImage.init(named: "1.jpg")
            
            //缩略图, 消息展示, 优化消息滑动时的卡顿
            //将原图按照一定的算法压缩处理成缩略图, 这里直接使用外部生成的缩略图,
            let thumImage = UIImage.init(named: "1_t.jpg")
            
            //将图片上传到服务器, 图片消息只是把图片的链接发送过去, 接收端根据链接展示图片
            //上传图片的代码就不多写, 具体上传方式根据自身服务器api决定, 这里假定图片已经上传到服务器上了, 并且返回了两个链接, 原图和缩略图
            //原图和缩略图链接
            let original = "http://www.vasueyun.cn/llgit/WZMChat/1.jpg"
            let thumbnail = "http://www.vasueyun.cn/llgit/WZMChat/1_t.jpg"
            
            //创建图片model
            let model = ADSChatMessageManager.createImageMessage(userModel: self.userModel!, thumbnail: thumbnail, original: original, thumImage: thumImage ?? UIImage(), oriImage: oriImage ?? UIImage(), isSender: true)
            self.sendMessageModel(message: model)
            
        } else if inputMoreType == ADSInputMoreType.ADSInputMoreTypeVideo.rawValue {
            //发送视频
            //选择视频的代码就不多写了, 这里假定已经选择了视频
            //上传到服务器, 获取视频链接
            let videoUrl = ""
            //封面图
            let coverImage = UIImage.init(named: "2_t.jpg")
            //将封面图上传到服务器, 获取封面图链接
            let coverUrl = "http://www.vasueyun.cn/llgit/WZMChat/2_t.jpg"
            //创建视频model
            let model = ADSChatMessageManager.createVideoMessage(userModel: self.userModel!, videoUrl: videoUrl, coverUrl: coverUrl, coverImage: coverImage ?? UIImage(), isSender: true)
            self.sendMessageModel(message: model)
        } else if inputMoreType == ADSInputMoreType.ADSInputMoreTypeVideo.rawValue {
            //发送定位 - 未实现
        } else if inputMoreType == ADSInputMoreType.ADSInputMoreTypeVideo.rawValue {
            //文件互传 - 未实现
        }
        
    }
    
    //发送消息
    func sendMessageModel(message: ADSChatMessageModel) {
        self.addMessageModel(message: message)
        
        //模拟消息发送中、发送成功、发送失败
        //根据需要可以将消息默认值设置为发送成功, 此处是为了演示效果
        let i = Int(arc4random()) % 2
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if i == 0 {
                message.sendType = ADSMessageSendType.WZMMessageSendTypeFailed
            }
            else  {
                message.sendType = ADSMessageSendType.WZMMessageSendTypeSuccess
            }
            
            if self?.userModel != nil {
                ADSChatDBManager.shared.updateMessageModel(message: message, userModel: self!.userModel!)
            } else if self?.groupModel != nil {
                ADSChatDBManager.shared.updateMessageModel(message: message, groupModel: self!.groupModel!)
            }
            
            self?.tableView.reloadData()
        }
        
        ADSChatNotificationManager.postSessionNotification()
    }
    
    //收到消息
    func receiveMessageModel(message: ADSChatMessageModel) {
        self.addMessageModel(message: message)
        
        ADSChatNotificationManager.postSessionNotification()
    }
    
    ///消息存储
    func addMessageModel(message: ADSChatMessageModel) {
        self.messageModels.append(message)
        self.tableView.reloadData()
        self.tableViewScrollToBottom(animated: true, duration: 0.25)
        
        if self.userModel != nil {
            ADSChatDBManager.shared.insertMessage(message: message, userModel: self.userModel!)
        } else if self.groupModel != nil {
            ADSChatDBManager.shared.insertMessage(message: message, groupModel: self.groupModel!)
        }
    }
    
    /// UITableViewDelegate,UITableViewDataSource
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.myInputView.chatResignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row > self.messageModels.count {
            let model = self.messageModels[indexPath.row]
            model.cacheModelSize()
            if model.msgType == ADSMessageType.ADSMessageTypeSystem {
                return model.modelH
            }
            
            if self.showName {
                return model.modelH + 45
            } else {
                return model.modelH + 32
            }
        } else {
            return 0.0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messageModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < self.messageModels.count {
            let model = self.messageModels[indexPath.row]
            
            if model.msgType == ADSMessageType.ADSMessageTypeSystem {
                guard let systemCell: ADSChatSystemCell = tableView.dequeueReusableCell(withIdentifier: "systemCell") as? ADSChatSystemCell else {
                    let systemCell = ADSChatSystemCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier: "systemCell")
                    return systemCell
                }
                systemCell.setConfig(model: model)
                return systemCell
                
            } else if model.msgType == ADSMessageType.ADSMessageTypeText {
                guard let textMessageCell: ADSChatTextMessageCell = tableView.dequeueReusableCell(withIdentifier: "textCell") as? ADSChatTextMessageCell else {
                    let textMessageCell = ADSChatTextMessageCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier: "textCell")
                    return textMessageCell
                }
                textMessageCell.setConfig(model: model, isShowName: self.showName)
                return textMessageCell
                
            } else if model.msgType == ADSMessageType.ADSMessageTypeImage {
                guard let imageMessageCell: ADSChatImageMessageCell = tableView.dequeueReusableCell(withIdentifier: "imageCell") as? ADSChatImageMessageCell else {
                    let imageMessageCell = ADSChatImageMessageCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier: "imageCell")
                    return imageMessageCell
                }
                imageMessageCell.setConfig(model: model, isShowName: self.showName)
                return imageMessageCell
                
            } else if model.msgType == ADSMessageType.ADSMessageTypeVoice {
                guard let voiceMessageCell: ADSChatVoiceMessageCell = tableView.dequeueReusableCell(withIdentifier: "voiceCell") as? ADSChatVoiceMessageCell else {
                    let voiceMessageCell = ADSChatVoiceMessageCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier: "voiceCell")
                    return voiceMessageCell
                }
                voiceMessageCell.setConfig(model: model, isShowName: self.showName)
                return voiceMessageCell
                
            } else if model.msgType == ADSMessageType.ADSMessageTypeVideo {
                guard let videoMessageCell: ADSChatVideoMessageCell = tableView.dequeueReusableCell(withIdentifier: "videoCell") as? ADSChatVideoMessageCell else {
                    let videoMessageCell = ADSChatVideoMessageCell.init(style: UITableViewCell.CellStyle.default, reuseIdentifier: "videoCell")
                    return videoMessageCell
                }
                videoMessageCell.setConfig(model: model, isShowName: self.showName)
                return videoMessageCell
                
            }
        }
        
        guard let noDataCell = tableView.dequeueReusableCell(withIdentifier: "noDataCell") else {
            return UITableViewCell.init(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "noDataCell")
        }
        
        return noDataCell
    }
    
    ///下拉加载处理
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y
        if y <= -WZM_LOADING_HEADER {
            if self.messageModels.count == 0 {return}
            let model = self.messageModels.first
            self.loadMessage(page: self.page)
        }
    }
    
    func beginLoading(page: Int) {
        if self.loading {return}
        self.loading = true
        if page > 0 {
            self.loadingView.startAnimating()
            self.tableView.contentInset = UIEdgeInsets.init(top: WZM_LOADING_HEADER, left: 0.0, bottom: 0.0, right: 0.0)
        }
    }
    
    func endLoading(page: Int) {
        if self.loading == false {return}
        self.loading = false
        if page == 0 {
            self.tableView.reloadData()
            self.tableViewScrollToBottom(animated: false, duration: 0.25)
        } else {
            self.loadingView.stopAnimating()
            if self.loadCount > 0 {
                self.tableView.contentInset = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                self.tableView.reloadData()
                let indexPath = IndexPath.init(row: self.loadCount, section: 0)
                self.tableView.scrollToRow(at: indexPath, at: UITableView.ScrollPosition.top, animated: false)
                let offset = self.tableView.contentOffset.y - WZM_LOADING_HEADER
                self.tableView.contentOffset = CGPoint.init(x: 0.0, y: offset)
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.tableView.contentInset = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
                }
            }
        }
    }
    
    func tableViewScrollToBottom(animated: Bool, duration: CGFloat) {
        if animated {
            let keyboardH = self.myInputView.keyboardH
            let contentH = self.tableView.contentSize.height
            let tableViewH = self.tableView.bounds.size.height
            
            var offsetY = 0.0
            if contentH < tableViewH {
                offsetY = max(contentH+keyboardH-tableViewH, 0)
            } else {
                offsetY = keyboardH
            }
            
            var TRect = self.tableView.frame
            TRect.origin.y = self.tableViewY - offsetY
            UIView.animate(withDuration: 0.25) {
                self.tableView.frame = TRect
                if self.messageModels.count > 0 {
                    self.tableView.scrollToRow(at: IndexPath.init(row: (self.messageModels.count-1), section: 0), at: UITableView.ScrollPosition.bottom, animated: false)
                }
            }
        } else {
            if self.messageModels.count > 0 {
                self.tableView.scrollToRow(at: IndexPath.init(row: (self.messageModels.count-1), section: 0), at: UITableView.ScrollPosition.bottom, animated: false)
            }
        }
    }
    
    // 录音按钮手势冲突处理
    func updateRecognizerDelegate(appear: Bool) {
        if appear {
            if self.recognizerDelegate == nil {
                self.recognizerDelegate = self.navigationController?.interactivePopGestureRecognizer?.delegate
            }
            self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        } else {
            self.navigationController?.interactivePopGestureRecognizer?.delegate = self.recognizerDelegate
        }
    }
    //是否响应触摸事件
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let navigationController = self.navigationController {
            if navigationController.viewControllers.count <= 1 {return false}
        }
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let point = touch.location(in: panGestureRecognizer.view)
            if point.y > self.CHAT_SCREEN_HEIGHT() - self.myInputView.toolViewH {
                return false
            }
            if point.x <= 100 {
                return true
            }
        }
        return false
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let tx = panGestureRecognizer.translation(in: panGestureRecognizer.view).x
            if tx < 0 {
                return false
            }
        }
        return true
    }
    //是否与其他手势共存，一般使用默认值(默认返回NO：不与任何手势共存)
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        //UIScrollView的滑动冲突
        if let view = otherGestureRecognizer.view {
            if view.isKind(of: UIScrollView.self) {
                let scrollView = view as! UIScrollView
                if scrollView.bounds.size.width >= scrollView.contentSize.width {
                    return false
                }
                if scrollView.contentOffset.x == 0 {
                    return true
                }
            }
        }
        
        return false
    }
    
    //屏蔽屏幕底部的系统手势
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        if self.deferredSystemGestures {
            return UIRectEdge.bottom
        }
        self.deferredSystemGestures = true
        return UIRectEdge.init(rawValue: 0)
    }
    
    //从数据库加载聊天记录
    func loadMessage(page: Int) {
        self.beginLoading(page: page)
        var messageModels:[ADSChatMessageModel] = []
        if let userModel = self.userModel {
            let table: ChatMessageModelTable = ADSChatDBManager.shared.createMessageTableName(model: userModel)
            messageModels = table.readMessages(orderBy: true, page: self.page)
        } else if let groupModel = self.groupModel {
            let table: ChatMessageModelTable = ADSChatDBManager.shared.createMessageTableName(model: groupModel)
            messageModels = table.readMessages(orderBy: true, page: self.page)
        }
        
        if messageModels.count > 0 {
            self.page = self.page + 1
        }
        
        for messageModel in messageModels {
            self.messageModels.append(messageModel)
        }
        
        if page == 0 {
            self.endLoading(page: page)
        } else {
            self.loadCount = messageModels.count
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: DispatchWorkItem(block: {
                self.endLoading(page: page)
            }))
        }
        
    }
    
}


extension ADSChatViewController {
    static var start: Double = 0
    static var msgType: Int = 1
}
