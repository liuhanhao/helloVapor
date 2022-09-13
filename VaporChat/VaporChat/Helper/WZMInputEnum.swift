//
//  WZNInputEnum.swift
//  翻译
//
//  Created by admin on 2022/9/13.
//

import Foundation

enum WZMKeyboardType: Int {
    //键盘状态
    case WZMKeyboardTypeIdle = 1, //闲置状态
         WZMKeyboardTypeSystem, //系统键盘
         WZMKeyboardTypeOther, //自定义键盘
         //扩展键盘类型 - 按需求自行扩展
         WZMKeyboardTypeEmoticon, //表情键盘
         WZMKeyboardTypeMore//More键盘
    
}

enum WZMInputBtnType: Int {
    case WZMInputBtnTypeNormal = 0,   //系统默认类型
         WZMInputBtnTypeTool,         //键盘工具按钮
         WZMInputBtnTypeMore         //More键盘按钮
}

enum WZMRecordType: Int {
    case WZMRecordTypeBegin = 0, //开始录音
         WZMRecordTypeCancel,    //取消录音
         WZMRecordTypeFinish    //完成录音
}

enum WZInputMoreType: Int {
    case WZInputMoreTypeImage = 0, //图片
         WZInputMoreTypeVideo,     //视频
         WZInputMoreTypeLocation,
         WZInputMoreTypeTransfer
}
