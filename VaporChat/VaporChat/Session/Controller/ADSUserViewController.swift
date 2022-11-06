//
//  ADSUserViewController.swift
//  VaporChat
//
//  Created by admin on 2022/10/26.
//

import UIKit

class ADSUserViewController: ADSBaseViewController, UITableViewDelegate, UITableViewDataSource {
    
    var users: [ADSChatUserModel] = []
    
    lazy var tableView: UITableView = {
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
        // Do any additional setup after loading the view.
        
        self.navigationItem.title = "好友"
        self.setupUI()
        self.loadUser()
    }
    
    func setupUI() {
        self.setRightItem()
        self.view.addSubview(self.tableView)
    }

    func loadUser() {
        // 删除所有对象
        self.users.removeAll { model in
            return true
        }
        if let userModels = ADSChatDBManager.shared.chatSqliteManager.chatUserTable.readAllUsers() {
            for i in 0..<userModels.count {
                self.users.append(userModels[i])
            }
        }
        self.tableView.reloadData()
    }
    
    func setRightItem() {
        let item = UIBarButtonItem.init(title: "添加好友", style: UIBarButtonItem.Style.plain, target: self, action: #selector(ADSUserViewController.rightItemClick(item:)))
        self.navigationItem.rightBarButtonItem = item
    }
    
    //添加一个好友
    @objc func rightItemClick(item: UIBarButtonItem) {
        var uid = "00002"
        if let lastModel = self.users.last {
            uid = "0000" + String((Int(lastModel.uid) ?? 0) + 1)
        }
        
        let model = ADSChatUserModel.init(uid: uid, name: "用户:" + uid, avatar: "http://sqb.wowozhe.com/images/touxiangs/10026820.jpg")
        model.showName = true
        
        self.users.append(model)
        self.tableView.reloadData()

        // 加入数据库
        let _ = ADSChatDBManager.shared.chatSqliteManager.chatUserTable.insertUser(userModel: model)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < self.users.count {
            let model = self.users[indexPath.row]
            
            let chatVC: ADSChatViewController = ADSChatViewController.init(userModel: model)
            chatVC.userModel = model
            chatVC.hidesBottomBarWhenPushed = true
            self.navigationController?.pushViewController(chatVC, animated: true)
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60.0;
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ADSUserTableViewCell? = tableView.dequeueReusableCell(withIdentifier: "ADSUserTableViewCell") as? ADSUserTableViewCell
        if cell == nil {
            cell = ADSUserTableViewCell.init(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "ADSUserTableViewCell")
        }
        
        if indexPath.row < self.users.count {
            let model = self.users[indexPath.row]
            cell!.setConfig(model: model)
        }
        
        return cell!
    }
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if indexPath.row < self.users.count {
            let model = self.users[indexPath.row]
            let deleteAction = UITableViewRowAction.init(style: UITableViewRowAction.Style.default, title: "删除") { action, indexPath in
                self.users.remove(at: indexPath.row)
                self.tableView.reloadData()
                let _ = ADSChatDBManager.shared.chatSqliteManager.chatUserTable.deleteUser(userId: model.uid)
                ADSChatNotificationManager.postSessionNotification()
            }
            return [deleteAction]
        }
        
        return nil
    }
    
}
