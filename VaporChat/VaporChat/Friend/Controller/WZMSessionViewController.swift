//
//  WZMSessionViewController.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class WZMSessionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var sessions: [ADSChatSessionModel] = []
    var isRefreshSession: Bool = false
    
    var type: Int = 1
    
    lazy var tableView = {
        var rect = self.view.bounds
        rect.origin.y = self.CHAT_NAV_BAR_H()
        rect.size.height = rect.size.height - (self.CHAT_NAV_BAR_H() + self.CHAT_TAB_BAR_H())
        
        let tableView = UITableView.init(frame: rect, style: UITableView.Style.plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInsetAdjustmentBehavior = UIScrollView.ContentInsetAdjustmentBehavior.never
        tableView.estimatedRowHeight = 0
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.tableFooterView = UIView.init()
        
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "会话"
        self.setupUI()
        self.loadSession()
        self.setRightItem()
        WZMChatNotificationManager.observerSessionNotification(instant: self, sel: #selector(self.receiveSessionNotification))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.isRefreshSession {
            self.isRefreshSession = false
            self.loadSession()
        }
    }
    
    func setupUI() {
        self.view.addSubview(self.tableView)
    }

    func loadSession() {
        self.sessions.removeAll { model in
            return true
        }
        if let sessionModels = WZMChatDBManager.shared.chatSqliteManager.chatSessionTable.readAllSessions() {
            for i in 0..<sessionModels.count {
                self.sessions.append(sessionModels[i])
            }
        }
        self.tableView.reloadData()
    }

    //收到刷新session的通知
    @objc func receiveSessionNotification() {
        self.isRefreshSession = true
    }
    
    func setRightItem() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "更改样式", style: UIBarButtonItem.Style.plain, target: self, action: #selector(self.rightItemClick))
    }
    
    @objc func rightItemClick() {
        if self.type == 4 {
            self.type = 0
        }
        
        for i in 0..<self.sessions.count {
            let session = self.sessions[i]
            if self.type == 0 {
                session.unreadNum = "0"
                session.silence = false
            } else if self.type == 1 {
                session.unreadNum = "18"
                session.silence = false
            } else if self.type == 2 {
                session.unreadNum = "18"
                session.silence = true
            } else if self.type == 3 {
                session.unreadNum = "100"
                session.silence = false
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < self.sessions.count {
            let session = self.sessions[indexPath.row]
            
            let chatVC = WZMChatViewController.init(sessionModel: session)
            chatVC.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(chatVC, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sessions.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: WZMSessionTableViewCell? = tableView.dequeueReusableCell(withIdentifier: "WZMSessionTableViewCell") as? WZMSessionTableViewCell
        if cell == nil {
            cell = WZMSessionTableViewCell.init(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "WZMSessionTableViewCell")
        }
        
        if indexPath.row < self.sessions.count {
            let model = self.sessions[indexPath.row]
            cell!.setConfig(model: model)
        }
        
        return cell!
    }
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.row < self.sessions.count {
            let session = self.sessions[indexPath.row]
            let deleteAction = UITableViewRowAction.init(style: UITableViewRowAction.Style.default, title: "删除") { action, indexPath in
                self.sessions.remove(at: indexPath.row)
                self.tableView.reloadData()
                let _ = WZMChatDBManager.shared.chatSqliteManager.chatSessionTable.deleteSession(sessionId: session.sid)
                WZMChatNotificationManager.postSessionNotification()
                
                //删除聊天记录
                if session.cluster {
                    let _ = WZMChatDBManager.shared.deleteGroupMessageTableName(groupId: session.sid)
                } else {
                    let _ = WZMChatDBManager.shared.deleteUserMessageTableName(userId: session.sid)
                }
                
            }
            return [deleteAction]
        }
        
        return nil
    }
    
    deinit {
        WZMChatNotificationManager.removeObserver(instant: self)
    }
}
