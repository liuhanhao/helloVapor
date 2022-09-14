//
//  ADSInputEnum.swift
//  翻译
//
//  Created by admin on 2022/9/13.
//

import Foundation

enum ADSKeyboardType: Int {
    //键盘状态
    case ADSKeyboardTypeIdle = 1, //闲置状态
         ADSKeyboardTypeSystem, //系统键盘
         ADSKeyboardTypeOther, //自定义键盘
         //扩展键盘类型 - 按需求自行扩展
         ADSKeyboardTypeEmoticon, //表情键盘
         ADSKeyboardTypeMore//More键盘
    
}

enum ADSInputBtnType: Int {
    case ADSInputBtnTypeNormal = 0,   //系统默认类型
         ADSInputBtnTypeTool,         //键盘工具按钮
         ADSInputBtnTypeMore         //More键盘按钮
}

enum ADSRecordType: Int {
    case ADSRecordTypeBegin = 0, //开始录音
         ADSRecordTypeCancel,    //取消录音
         ADSRecordTypeFinish    //完成录音
}

enum WZInputMoreType: Int {
    case WZInputMoreTypeImage = 0, //图片
         WZInputMoreTypeVideo,     //视频
         WZInputMoreTypeLocation,
         WZInputMoreTypeTransfer
}
