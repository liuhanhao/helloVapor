//
//  WZMChatViewController.swift
//  VaporChat
//
//  Created by admin on 2022/10/31.
//

import UIKit

// ,UITableViewDelegate,UITableViewDataSource,UIGestureRecognizerDelegate
class WZMChatViewController: UIViewController {

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
    
    

}
