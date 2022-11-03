//
//  WZMChatViewController.swift
//  VaporChat
//
//  Created by admin on 2022/10/31.
//

import UIKit

let WZM_LOADING_HEADER = 50.0

// ,UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate
class WZMChatViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate,WZMInputViewDelegate {
    
    ///列表相关
    var tableViewY: CGFloat = NSObject.init().CHAT_NAV_BAR_H()
    var messageModels: [ADSChatMessageModel] = []
    lazy var tableView = {
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
            _myInputView.text = WZMChatDBManager.shared.draft(model: userModel)
        } else if let groupModel = self.groupModel {
            _myInputView.text = WZMChatDBManager.shared.draft(model: groupModel)
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
        _loadingView.hidesWhenStopped = true;
        
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messageModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < self.messageModels.count {
//            var cell: adsba
        }
        return UITableViewCell.init()
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
            let table: ChatMessageModelTable = WZMChatDBManager.shared.createMessageTableName(model: userModel)
            messageModels = table.readMessages(orderBy: true, page: self.page)
        } else if let groupModel = self.groupModel {
            let table: ChatMessageModelTable = WZMChatDBManager.shared.createMessageTableName(model: groupModel)
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
