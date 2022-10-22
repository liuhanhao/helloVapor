//
//  ADSChatHelper.swift
//  VaporChat
//
//  Created by admin on 2022/9/14.
//

import Foundation
import UIKit

extension NSObject {
    
    func CHAT_SCREEN_WIDTH() -> CGFloat {
        return ADSInputHelper.sharedHelper.screenW()
    }
    
    func CHAT_SCREEN_HEIGHT() -> CGFloat {
        return ADSInputHelper.sharedHelper.screenH()
    }
    
    func CHAT_IPHONEX() -> Bool {
        return ADSInputHelper.sharedHelper.iPhoneX()
    }

    func CHAT_NAV_BAR_H() -> CGFloat {
        return ADSInputHelper.sharedHelper.navBarH()
    }
    
    func CHAT_TAB_BAR_H() -> CGFloat {
        return ADSInputHelper.sharedHelper.tabBarH()
    }
    
    func CHAT_BOTTOM_H() -> CGFloat {
        return ADSInputHelper.sharedHelper.iPhoneXBottomH()
    }
    
    //默认图
    func CHAT_BAD_IMAGE() -> UIImage? {
        return ADSInputHelper.otherImageNamed(name: "wzm_chat_default")
    }

}

class ADSChatHelper: NSObject {
    
    static let sharedHelper:ADSChatHelper = ADSChatHelper.init()
    
    var memoryCache: [String:Data] = [:]
    lazy var cachePath: String = {
        let array = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        var path = array.first
        if path != nil {
            return path!.appending("/chatCache")
        } else {
            return ""
        }
    }()
    lazy var senderBubbleImage: UIImage = {
        let image: UIImage = ADSInputHelper.otherImageNamed(name: "wzm_chat_bj2")!
        let size = image.size
        let _senderBubbleImage = image.stretchableImage(withLeftCapWidth: Int(size.width/2), topCapHeight: Int(size.height*0.8))
        return _senderBubbleImage
    }()
    lazy var receiverBubbleImage: UIImage = {
        let image: UIImage = ADSInputHelper.otherImageNamed(name: "wzm_chat_bj1")!
        let size = image.size
        let _receiverBubbleImage = image.stretchableImage(withLeftCapWidth: Int(size.width/2), topCapHeight: Int(size.height*0.8))
        return _receiverBubbleImage
    }()
    
    
    override init() {
        
        
    }
    
    static func nowTimestamp() -> TimeInterval {
        let date = Date.init(timeIntervalSinceNow: 0)
        let time = date.timeIntervalSince1970 * 1000
        return time
    }
    
    
    
    /// 文件管理
    func fileExistsAtPath(filePath: String) -> Bool {
        if FileManager.default.fileExists(atPath: filePath) {
            return true
        } else {
            print("fileExistsAtPath:文件未找到")
            return false
        }
    }
    func createDirectoryAtPath(path: String) -> Bool {
        let pointer = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 0)
        let isExists = FileManager.default.fileExists(atPath: path, isDirectory: pointer)
        let isDirectory = pointer[0]
        if isExists && isDirectory.boolValue {
            return true
        }
        
        do {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch error {
            <#statements#>
        }
        
        let result =
        
    }

    - (BOOL)createDirectoryAtPath:(NSString *)path{
        BOOL isDirectory;
        BOOL isExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
        if (isExists && isDirectory) {
            return YES;
        }
        NSError *error = nil;
        BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:path
                                                withIntermediateDirectories:YES
                                                                 attributes:nil
                                                                      error:&error];
        if (error) {
            NSLog(@"创建文件夹失败:%@",error);
        }
        return result;
    }

    - (BOOL)writeFile:(id)file toPath:(NSString *)path{
        BOOL isOK = [file writeToFile:path atomically:YES];
        NSLog(@"文件存储路径为:%@",path);
        return isOK;
    }

    - (BOOL)deleteFileAtPath:(NSString *)filePath error:(NSError **)error{
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
            return [[NSFileManager defaultManager] removeItemAtPath:filePath error:error];
        }
        NSLog(@"deleteFileAtPath:error:路径未找到");
        return YES;
    }
    
}
